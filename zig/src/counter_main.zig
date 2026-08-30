const std = @import("std");
const hondo = @import("hondo");
const counter_io = @import("counter_io.zig");

const counter_bundle = @embedFile("generated/counter.js");
const grid_width = 64;
const grid_height = 3;
const instructions = "Enter/Space: increment  q/Esc/Ctrl-C: quit";

const CounterError = error{
    SmokeAssertionFailed,
};

const CounterApp = struct {
    allocator: std.mem.Allocator,
    scene: *hondo.scene.Scene,
    runtime: hondo.runtime.Runtime,
    grid: hondo.cell_grid.CellGrid,

    fn init(allocator: std.mem.Allocator) !CounterApp {
        const scene = try allocator.create(hondo.scene.Scene);
        errdefer allocator.destroy(scene);
        scene.* = try hondo.scene.Scene.init(allocator);
        errdefer scene.deinit();

        var runtime = try hondo.runtime.Runtime.init();
        errdefer runtime.deinit();
        try runtime.installSceneBridge(scene);
        try runtime.eval(counter_bundle, "hondo-counter-executable.js");

        var grid = try hondo.cell_grid.CellGrid.init(allocator, grid_width, grid_height);
        errdefer grid.deinit();

        return .{
            .allocator = allocator,
            .scene = scene,
            .runtime = runtime,
            .grid = grid,
        };
    }

    fn deinit(self: *CounterApp) void {
        self.runtime.eval(
            "globalThis.__hondoCounterDispose?.();",
            "hondo-counter-executable-dispose.js",
        ) catch {};
        self.grid.deinit();
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
        try hondo.scene_renderer.render(self.scene, &self.grid);
        self.grid.paintUtf8(0, 1, instructions, self.grid.width);
    }

    fn assertCount(self: *CounterApp, expected: []const u8) !void {
        try self.render();
        const row = try self.grid.rowUtf8(self.allocator, 0);
        defer self.allocator.free(row);
        if (!std.mem.startsWith(u8, row, expected)) return CounterError.SmokeAssertionFailed;
    }

    fn writeFrame(self: *CounterApp) !void {
        try self.render();
        const frame = try hondo.terminal.frame.encode(self.allocator, &self.grid);
        defer self.allocator.free(frame);
        try counter_io.writeAll(counter_io.stdout_fd, frame);
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
    var app = try CounterApp.init(allocator);
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

    var app = try CounterApp.init(allocator);
    defer app.deinit();
    try app.writeFrame();

    input_loop: while (true) {
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
