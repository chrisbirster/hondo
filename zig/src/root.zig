const std = @import("std");

pub const quickjs = @import("quickjs.zig");
pub const scene = @import("scene.zig");
pub const version = "0.1.0-alpha.0";

pub const RuntimeBoundary = enum {
    solid,
    hondo,
    zig,
};

test "foundation exposes a version" {
    try std.testing.expect(version.len > 0);
}

test {
    _ = quickjs;
    _ = scene;
}
