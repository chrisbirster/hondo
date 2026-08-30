const std = @import("std");
const scene_module = @import("scene.zig");

pub const FocusError = error{
    NotFocusable,
};

pub const Change = struct {
    previous: ?scene_module.NodeId,
    current: ?scene_module.NodeId,
};

pub const Manager = struct {
    focused: ?scene_module.NodeId = null,
    last_request: u64 = 0,

    pub fn set(self: *Manager, scene: *scene_module.Scene, node_id: scene_module.NodeId) !?Change {
        _ = try scene.getNode(node_id);
        if (!try isFocusable(scene, node_id)) return FocusError.NotFocusable;
        if (self.focused == node_id) return null;

        const change = Change{ .previous = self.focused, .current = node_id };
        self.focused = node_id;
        return change;
    }

    pub fn syncRequested(self: *Manager, scene: *scene_module.Scene) !?Change {
        var requested_id: ?scene_module.NodeId = null;
        var requested_sequence = self.last_request;

        for (scene.nodes.items) |maybe_node| {
            const node = maybe_node orelse continue;
            if (!try isFocusable(scene, node.id)) continue;
            const raw = (try scene.getPropertyJson(node.id, "focusRequest")) orelse continue;
            const sequence = std.fmt.parseInt(u64, raw, 10) catch continue;
            if (sequence <= requested_sequence) continue;
            requested_sequence = sequence;
            requested_id = node.id;
        }

        const node_id = requested_id orelse return null;
        self.last_request = requested_sequence;
        return self.set(scene, node_id);
    }

    pub fn clear(self: *Manager) ?Change {
        const previous = self.focused orelse return null;
        self.focused = null;
        return .{ .previous = previous, .current = null };
    }

    pub fn target(self: *const Manager) ?scene_module.NodeId {
        return self.focused;
    }
};

fn isFocusable(scene: *scene_module.Scene, node_id: scene_module.NodeId) !bool {
    const focusable = (try scene.getPropertyJson(node_id, "focusable")) orelse return false;
    return std.mem.eql(u8, focusable, "true");
}

test "focus manager only targets focusable scene nodes" {
    var scene = try scene_module.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.createElement(1, "box");
    try scene.createElement(2, "input");
    try scene.setPropertyJson(2, "focusable", "true");

    var manager = Manager{};
    try std.testing.expectError(FocusError.NotFocusable, manager.set(&scene, 1));

    const first = (try manager.set(&scene, 2)).?;
    try std.testing.expectEqual(@as(?scene_module.NodeId, null), first.previous);
    try std.testing.expectEqual(@as(?scene_module.NodeId, 2), first.current);
    try std.testing.expectEqual(@as(?scene_module.NodeId, 2), manager.target());
    try std.testing.expect((try manager.set(&scene, 2)) == null);

    const cleared = manager.clear().?;
    try std.testing.expectEqual(@as(?scene_module.NodeId, 2), cleared.previous);
    try std.testing.expectEqual(@as(?scene_module.NodeId, null), cleared.current);
}

test "focus manager consumes the newest declarative focus request once" {
    var scene = try scene_module.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.createElement(1, "input");
    try scene.createElement(2, "input");
    try scene.createElement(3, "box");
    try scene.setPropertyJson(1, "focusable", "true");
    try scene.setPropertyJson(2, "focusable", "true");
    try scene.setPropertyJson(1, "focusRequest", "1");
    try scene.setPropertyJson(2, "focusRequest", "2");
    try scene.setPropertyJson(3, "focusRequest", "99");

    var manager = Manager{};
    const first = (try manager.syncRequested(&scene)).?;
    try std.testing.expectEqual(@as(?scene_module.NodeId, 2), first.current);
    try std.testing.expectEqual(@as(u64, 2), manager.last_request);
    try std.testing.expect((try manager.syncRequested(&scene)) == null);

    try scene.setPropertyJson(1, "focusRequest", "3");
    const second = (try manager.syncRequested(&scene)).?;
    try std.testing.expectEqual(@as(?scene_module.NodeId, 2), second.previous);
    try std.testing.expectEqual(@as(?scene_module.NodeId, 1), second.current);
}
