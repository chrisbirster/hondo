const std = @import("std");
const cell_grid = @import("../render/cell_grid.zig");
const frame = @import("frame.zig");

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    current: cell_grid.CellGrid,
    previous: cell_grid.CellGrid,
    invalidated: bool = true,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Renderer {
        var current = try cell_grid.CellGrid.init(allocator, width, height);
        errdefer current.deinit();
        var previous = try cell_grid.CellGrid.init(allocator, width, height);
        errdefer previous.deinit();

        return .{
            .allocator = allocator,
            .current = current,
            .previous = previous,
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.current.deinit();
        self.previous.deinit();
        self.* = undefined;
    }

    pub fn grid(self: *Renderer) *cell_grid.CellGrid {
        return &self.current;
    }

    pub fn invalidate(self: *Renderer) void {
        self.invalidated = true;
    }

    pub fn resize(self: *Renderer, width: usize, height: usize) !bool {
        if (self.current.width == width and self.current.height == height) return false;

        var next_current = try cell_grid.CellGrid.init(self.allocator, width, height);
        errdefer next_current.deinit();
        var next_previous = try cell_grid.CellGrid.init(self.allocator, width, height);
        errdefer next_previous.deinit();

        self.current.deinit();
        self.previous.deinit();
        self.current = next_current;
        self.previous = next_previous;
        self.invalidated = true;
        return true;
    }

    pub fn encode(self: *Renderer) ![]u8 {
        const bytes = if (self.invalidated)
            try frame.encode(self.allocator, &self.current)
        else
            try frame.encodeDiff(self.allocator, &self.previous, &self.current);
        errdefer self.allocator.free(bytes);

        try self.previous.copyFrom(&self.current);
        self.invalidated = false;
        return bytes;
    }
};

test "renderer sends a full frame once then incremental cell diffs" {
    var renderer = try Renderer.init(std.testing.allocator, 4, 1);
    defer renderer.deinit();

    renderer.grid().paintUtf8(0, 0, "A", 4);
    const first = try renderer.encode();
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("\x1b[H\x1b[2KA   ", first);

    renderer.grid().clear();
    renderer.grid().paintUtf8(0, 0, "B", 4);
    const second = try renderer.encode();
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings("\x1b[1;1HB", second);

    const unchanged = try renderer.encode();
    defer std.testing.allocator.free(unchanged);
    try std.testing.expectEqualStrings("", unchanged);
}

test "renderer resize invalidates the previous frame" {
    var renderer = try Renderer.init(std.testing.allocator, 4, 1);
    defer renderer.deinit();

    _ = try renderer.encode();
    try std.testing.expect(try renderer.resize(2, 1));
    try std.testing.expect(!try renderer.resize(2, 1));

    renderer.grid().paintUtf8(0, 0, "C", 2);
    const bytes = try renderer.encode();
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1b[H\x1b[2KC ", bytes);
}
