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

    pub fn set(self: *Manager, scene: *scene_module.Scene, node_id: scene_module.NodeId) !?Change {
        _ = try scene.getNode(node_id);
        const focusable = (try scene.getPropertyJson(node_id, "focusable")) orelse return FocusError.NotFocusable;
        if (!std.mem.eql(u8, focusable, "true")) return FocusError.NotFocusable;
        if (self.focused == node_id) return null;

        const change = Change{ .previous = self.focused, .current = node_id };
        self.focused = node_id;
        return change;
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
