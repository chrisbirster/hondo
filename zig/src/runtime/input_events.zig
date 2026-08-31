const std = @import("std");
const quickjs_runtime = @import("quickjs.zig");
const node_events = @import("node_events.zig");
const scene_module = @import("../scene.zig");
const terminal_input = @import("../terminal/input.zig");
const focus = @import("../focus.zig");

pub fn dispatch(
    allocator: std.mem.Allocator,
    runtime: *quickjs_runtime.Runtime,
    target_id: scene_module.NodeId,
    event: terminal_input.Event,
) !node_events.Result {
    const encoded = try encode(allocator, event);
    defer if (encoded.owned) allocator.free(encoded.payload);
    return node_events.dispatch(runtime, target_id, encoded.event_type, encoded.payload);
}

pub fn dispatchFocused(
    allocator: std.mem.Allocator,
    runtime: *quickjs_runtime.Runtime,
    scene: *scene_module.Scene,
    manager: *focus.Manager,
    event: terminal_input.Event,
) !node_events.Result {
    if (try manager.syncRequested(scene)) |change| {
        try dispatchFocusChange(runtime, change);
    }

    const result = if (manager.target()) |target|
        try dispatch(allocator, runtime, target, event)
    else
        node_events.Result{ .default_prevented = false };

    var declarative_focus_changed = false;
    if (try manager.syncRequested(scene)) |change| {
        declarative_focus_changed = true;
        try dispatchFocusChange(runtime, change);
    }

    if (!declarative_focus_changed and !result.default_prevented) {
        if (traversalDirection(event)) |direction| {
            if (try manager.traverse(scene, direction, true)) |change| {
                try dispatchFocusChange(runtime, change);
            }
        }
    }

    return result;
}

pub fn dispatchFocusChange(
    runtime: *quickjs_runtime.Runtime,
    change: focus.Change,
) !void {
    if (change.previous) |previous| {
        _ = try node_events.dispatch(runtime, previous, "focusOut", "{}");
    }
    if (change.current) |current| {
        _ = try node_events.dispatch(runtime, current, "focusIn", "{}");
    }
}

const Encoded = struct {
    event_type: []const u8,
    payload: []const u8,
    owned: bool = false,
};

fn encode(allocator: std.mem.Allocator, event: terminal_input.Event) !Encoded {
    return switch (event) {
        .key => |key| encodeKey(allocator, key),
        .mouse => |mouse| .{
            .event_type = "mouse",
            .payload = try std.fmt.allocPrint(
                allocator,
                "{{\"x\":{d},\"y\":{d},\"button\":\"{s}\",\"action\":\"{s}\",\"shift\":{},\"alt\":{},\"ctrl\":{}}}",
                .{
                    mouse.x,
                    mouse.y,
                    mouseButtonName(mouse.button),
                    mouseActionName(mouse.action),
                    mouse.shift,
                    mouse.alt,
                    mouse.ctrl,
                },
            ),
            .owned = true,
        },
        .focus => |focus_event| switch (focus_event) {
            .in => .{ .event_type = "terminalFocusIn", .payload = "{}" },
            .out => .{ .event_type = "terminalFocusOut", .payload = "{}" },
        },
    };
}

fn encodeKey(allocator: std.mem.Allocator, key: terminal_input.Key) !Encoded {
    return switch (key) {
        .codepoint => |codepoint| .{
            .event_type = "key",
            .payload = try std.fmt.allocPrint(
                allocator,
                "{{\"kind\":\"codepoint\",\"codepoint\":{d}}}",
                .{codepoint},
            ),
            .owned = true,
        },
        .enter => .{ .event_type = "key", .payload = "{\"kind\":\"enter\"}" },
        .backspace => .{ .event_type = "key", .payload = "{\"kind\":\"backspace\"}" },
        .tab => .{ .event_type = "key", .payload = "{\"kind\":\"tab\"}" },
        .shift_tab => .{ .event_type = "key", .payload = "{\"kind\":\"shiftTab\"}" },
        .escape => .{ .event_type = "key", .payload = "{\"kind\":\"escape\"}" },
        .ctrl_c => .{ .event_type = "key", .payload = "{\"kind\":\"ctrlC\"}" },
        .up => .{ .event_type = "key", .payload = "{\"kind\":\"up\"}" },
        .down => .{ .event_type = "key", .payload = "{\"kind\":\"down\"}" },
        .left => .{ .event_type = "key", .payload = "{\"kind\":\"left\"}" },
        .right => .{ .event_type = "key", .payload = "{\"kind\":\"right\"}" },
    };
}

fn traversalDirection(event: terminal_input.Event) ?focus.Direction {
    return switch (event) {
        .key => |key| switch (key) {
            .tab => .forward,
            .shift_tab => .backward,
            else => null,
        },
        else => null,
    };
}

fn mouseButtonName(button: terminal_input.MouseButton) []const u8 {
    return switch (button) {
        .none => "none",
        .left => "left",
        .middle => "middle",
        .right => "right",
        .wheel_up => "wheelUp",
        .wheel_down => "wheelDown",
    };
}

fn mouseActionName(action: terminal_input.MouseAction) []const u8 {
    return switch (action) {
        .press => "press",
        .release => "release",
        .move => "move",
        .scroll => "scroll",
    };
}

test "terminal event routing encodes key mouse and terminal focus payloads" {
    const enter = try encode(std.testing.allocator, .{ .key = .enter });
    try std.testing.expectEqualStrings("key", enter.event_type);
    try std.testing.expectEqualStrings("{\"kind\":\"enter\"}", enter.payload);

    const backspace = try encode(std.testing.allocator, .{ .key = .backspace });
    try std.testing.expectEqualStrings("key", backspace.event_type);
    try std.testing.expectEqualStrings("{\"kind\":\"backspace\"}", backspace.payload);

    const tab = try encode(std.testing.allocator, .{ .key = .tab });
    try std.testing.expectEqualStrings("{\"kind\":\"tab\"}", tab.payload);
    const shift_tab = try encode(std.testing.allocator, .{ .key = .shift_tab });
    try std.testing.expectEqualStrings("{\"kind\":\"shiftTab\"}", shift_tab.payload);

    const codepoint = try encode(std.testing.allocator, .{ .key = .{ .codepoint = 'λ' } });
    defer std.testing.allocator.free(codepoint.payload);
    try std.testing.expect(codepoint.owned);
    try std.testing.expectEqualStrings("{\"kind\":\"codepoint\",\"codepoint\":955}", codepoint.payload);

    const mouse = try encode(std.testing.allocator, .{ .mouse = .{
        .x = 3,
        .y = 4,
        .button = .left,
        .action = .press,
        .ctrl = true,
    } });
    defer std.testing.allocator.free(mouse.payload);
    try std.testing.expectEqualStrings("mouse", mouse.event_type);
    try std.testing.expect(std.mem.indexOf(u8, mouse.payload, "\"ctrl\":true") != null);

    const terminal_focus = try encode(std.testing.allocator, .{ .focus = .in });
    try std.testing.expectEqualStrings("terminalFocusIn", terminal_focus.event_type);
}

test "focused terminal key routing updates Solid through the node event bridge" {
    const counter_bundle = @embedFile("../generated/counter.js");

    var scene = try scene_module.Scene.init(std.testing.allocator);
    defer scene.deinit();

    var runtime = try quickjs_runtime.Runtime.init();
    defer runtime.deinit();
    try runtime.installSceneBridge(&scene);
    try runtime.eval(counter_bundle, "hondo-counter-focused-key.js");

    var manager = focus.Manager{};
    const change = (try manager.set(&scene, 1)).?;
    try dispatchFocusChange(&runtime, change);

    const result = try dispatch(
        std.testing.allocator,
        &runtime,
        manager.target().?,
        .{ .key = .enter },
    );
    try std.testing.expect(result.default_prevented);
    try std.testing.expectEqualStrings("Count: 1", (try scene.getNode(2)).text.?);

    const cleared = manager.clear().?;
    try dispatchFocusChange(&runtime, cleared);
    try runtime.eval(
        "globalThis.__hondoCounterDispose();",
        "hondo-counter-focused-key-dispose.js",
    );
}
