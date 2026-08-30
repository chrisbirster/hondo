const std = @import("std");
const hondo = @import("hondo");
const counter_io = @import("counter_io.zig");

const counter_bundle = @embedFile("generated/counter.js");
const grid_width = 64;
const grid_height = 3;
const resize_poll_ms = 50;
const instructions = "Enter/Space: increment  q/Esc/Ctrl-C: quit";

const CounterError = error{
    SmokeAssertionFailed,
};

const CounterApp = struct {
    allocator: std.mem.Allocator,
    scene: *hondo.scene.Scene,
    runtime: hondo.runtime.Runtime,
    renderer: hondo.terminal.renderer.Renderer,

    fn init(allocator: std.mem.Allocator, width: usize, height: usize) !CounterApp {
        const scene = try allocator.create(hondo.scene.Scene);
        errdefer allocator.destroy(scene);
        scene.* = try hondo.scene.Scene.init(allocator);
        errdefer scene.deinit();

        var runtime = try hondo.runtime.Runtime.init();
        errdefer runtime.deinit();
        try runtime.installSceneBridge(scene);
        try runtime.eval(counter_bundle, "hondo-counter-executable.js");

        var renderer = try hondo.terminal.renderer.Renderer.init(allocator, width, height);
        errdefer renderer.deinit();

        return .{
            .allocator = allocator,
            .scene = scene,
            .runtime = runtime,
            .renderer = renderer,
        };
    }

    fn deinit(self: *CounterApp) void {
        self.runtime.eval(
            "globalThis.__hondoCounterDispose?.();",
            "hondo-counter-executable-dispose.js",
        ) catch {};
        self.renderer.deinit();
        self.runtime.deinit();
        self.scene.deinit();
        self.allocator.destroy(self.scene);
        self.* = undefined;
    }

    fn increment(self: *CounterApp) !void {
        try hondo.native_events.dispatch(
            &self.runtime,
            "counter.increment",
            "{\"source\":\"terminal\"}",
        );
    }

    fn render(self: *CounterApp) !void {
        const grid = self.renderer.grid();
        try hondo.scene_renderer.render(self.scene, grid);
        grid.paintUtf8(0, 1, instructions, grid.width);
    }

    fn resize(self: *CounterApp, width: usize, height: usize) !bool {
        return self.renderer.resize(width, height);
    }

    fn assertCount(self: *CounterApp, expected: []const u8) !void {
        try self.render();
        const row = try self.renderer.grid().rowUtf8(self.allocator, 0);
        defer self.allocator.free(row);
        if (!std.mem.startsWith(u8, row, expected)) return CounterError.SmokeAssertionFailed;
    }

    fn writeFrame(self: *CounterApp) !void {
        try self.render();
        const bytes = try self.renderer.encode();
        defer self.allocator.free(bytes);
        if (bytes.len != 0) try counter_io.writeAll(counter_io.stdout_fd, bytes);
    }
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const smoke = hasArg(args, "--smoke");
    const once = hasArg(args, "--once");

    if (smoke) {
        try runSmoke(init.gpa);
        return;
    }

    try runInteractive(init.gpa, once);
}

fn runSmoke(allocator: std.mem.Allocator) !void {
    var app = try CounterApp.init(allocator, grid_width, grid_height);
    defer app.deinit();

    try app.assertCount("Count: 0");
    try counter_io.writeAll(counter_io.stdout_fd, "HONDO_SMOKE_INITIAL=Count: 0\n");

    try app.increment();
    try app.assertCount("Count: 1");
    try counter_io.writeAll(counter_io.stdout_fd, "HONDO_SMOKE_UPDATED=Count: 1\n");
}

fn runInteractive(allocator: std.mem.Allocator, once: bool) !void {
    var session = try hondo.terminal.session.Session.begin(
        counter_io.stdin_fd,
        counter_io.stdout_fd,
    );
    defer session.restore() catch {};

    const restore = try hondo.terminal.control.restoreSequence(allocator);
    defer allocator.free(restore);
    defer counter_io.writeAll(counter_io.stdout_fd, restore) catch {};

    const begin = try hondo.terminal.control.beginSequence(allocator);
    defer allocator.free(begin);
    try counter_io.writeAll(counter_io.stdout_fd, begin);

    const initial_size = hondo.terminal.size.query(counter_io.stdout_fd) catch hondo.terminal.size.Size{
        .width = grid_width,
        .height = grid_height,
    };
    var size_tracker = hondo.terminal.size.Tracker.initKnown(initial_size);

    var app = try CounterApp.init(allocator, initial_size.width, initial_size.height);
    defer app.deinit();
    try app.writeFrame();

    input_loop: while (true) {
        const has_input = try hondo.terminal.wait.readable(counter_io.stdin_fd, resize_poll_ms);

        const resize = size_tracker.poll(counter_io.stdout_fd) catch null;
        if (resize) |new_size| {
            if (try app.resize(new_size.width, new_size.height)) try app.writeFrame();
        }

        if (!has_input) continue;
        const byte = (try counter_io.readByte(counter_io.stdin_fd)) orelse break;
        const input = [_]u8{byte};
        const decoded = hondo.terminal.input.decode(&input) orelse continue;

        switch (decoded.key) {
            .enter => {
                try app.increment();
                try app.writeFrame();
                if (once) break :input_loop;
            },
            .codepoint => |codepoint| {
                if (codepoint == 'q') break :input_loop;
                if (codepoint == ' ') {
                    try app.increment();
                    try app.writeFrame();
                    if (once) break :input_loop;
                }
            },
            .escape, .ctrl_c => break :input_loop,
            else => {},
        }
    }
}

fn hasArg(args: []const [:0]const u8, expected: []const u8) bool {
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, expected)) return true;
    }
    return false;
}
