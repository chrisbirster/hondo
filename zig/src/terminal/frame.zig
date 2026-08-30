const std = @import("std");
const cell_grid = @import("../render/cell_grid.zig");
const control = @import("control.zig");

pub fn encode(allocator: std.mem.Allocator, grid: *const cell_grid.CellGrid) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, control.home);
    for (0..grid.height) |y| {
        try output.appendSlice(allocator, control.clear_line);
        const row = try grid.rowUtf8(allocator, y);
        defer allocator.free(row);
        try output.appendSlice(allocator, row);
        if (y + 1 < grid.height) try output.appendSlice(allocator, "\r\n");
    }

    return output.toOwnedSlice(allocator);
}

test "terminal frame redraws every cell-grid row from home" {
    var grid = try cell_grid.CellGrid.init(std.testing.allocator, 4, 2);
    defer grid.deinit();
    grid.paintUtf8(0, 0, "Hi", 4);
    grid.paintUtf8(1, 1, "λ", 3);

    const bytes = try encode(std.testing.allocator, &grid);
    defer std.testing.allocator.free(bytes);

    try std.testing.expectEqualStrings(
        "\x1b[H\x1b[2KHi  \r\n\x1b[2K λ  ",
        bytes,
    );
}
