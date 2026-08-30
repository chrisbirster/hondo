const std = @import("std");
const cell_grid = @import("../render/cell_grid.zig");
const control = @import("control.zig");

pub const FrameError = error{
    DimensionMismatch,
};

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

pub fn encodeDiff(
    allocator: std.mem.Allocator,
    previous: *const cell_grid.CellGrid,
    current: *const cell_grid.CellGrid,
) ![]u8 {
    if (!previous.sameDimensions(current)) return FrameError.DimensionMismatch;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    for (0..current.height) |y| {
        var x: usize = 0;
        while (x < current.width) {
            if (cellsEqual(previous, current, x, y)) {
                x += 1;
                continue;
            }

            const run_start = x;
            while (x < current.width and !cellsEqual(previous, current, x, y)) : (x += 1) {}

            try appendCursorPosition(allocator, &output, y + 1, run_start + 1);
            for (run_start..x) |run_x| {
                try appendCodepoint(allocator, &output, current.get(run_x, y).?.codepoint);
            }
        }
    }

    return output.toOwnedSlice(allocator);
}

fn cellsEqual(
    previous: *const cell_grid.CellGrid,
    current: *const cell_grid.CellGrid,
    x: usize,
    y: usize,
) bool {
    return previous.get(x, y).?.codepoint == current.get(x, y).?.codepoint;
}

fn appendCursorPosition(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    row: usize,
    column: usize,
) !void {
    const sequence = try std.fmt.allocPrint(allocator, "\x1b[{d};{d}H", .{ row, column });
    defer allocator.free(sequence);
    try output.appendSlice(allocator, sequence);
}

fn appendCodepoint(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    codepoint: u21,
) !void {
    var buffer: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(codepoint, &buffer) catch {
        try output.appendSlice(allocator, "�");
        return;
    };
    try output.appendSlice(allocator, buffer[0..len]);
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

test "terminal diff emits only contiguous changed cell runs" {
    var previous = try cell_grid.CellGrid.init(std.testing.allocator, 5, 2);
    defer previous.deinit();
    var current = try cell_grid.CellGrid.init(std.testing.allocator, 5, 2);
    defer current.deinit();

    current.paintUtf8(1, 0, "AB", 2);
    current.set(4, 0, 'Z');
    current.set(0, 1, 'λ');

    const bytes = try encodeDiff(std.testing.allocator, &previous, &current);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings(
        "\x1b[1;2HAB\x1b[1;5HZ\x1b[2;1Hλ",
        bytes,
    );

    try previous.copyFrom(&current);
    const unchanged = try encodeDiff(std.testing.allocator, &previous, &current);
    defer std.testing.allocator.free(unchanged);
    try std.testing.expectEqualStrings("", unchanged);
}

test "terminal diff rejects grids with different dimensions" {
    var previous = try cell_grid.CellGrid.init(std.testing.allocator, 2, 1);
    defer previous.deinit();
    var current = try cell_grid.CellGrid.init(std.testing.allocator, 3, 1);
    defer current.deinit();

    try std.testing.expectError(
        FrameError.DimensionMismatch,
        encodeDiff(std.testing.allocator, &previous, &current),
    );
}
