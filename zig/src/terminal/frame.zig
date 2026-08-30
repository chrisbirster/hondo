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

            var run_start = @min(glyphStart(previous, x, y), glyphStart(current, x, y));
            var run_end = @max(glyphEnd(previous, x, y), glyphEnd(current, x, y));
            x += 1;

            while (x < current.width) {
                if (x < run_end) {
                    if (!cellsEqual(previous, current, x, y)) {
                        run_start = @min(run_start, @min(glyphStart(previous, x, y), glyphStart(current, x, y)));
                        run_end = @max(run_end, @max(glyphEnd(previous, x, y), glyphEnd(current, x, y)));
                    }
                    x += 1;
                    continue;
                }

                if (cellsEqual(previous, current, x, y)) break;
                const next_start = @min(glyphStart(previous, x, y), glyphStart(current, x, y));
                if (next_start > run_end) break;
                run_start = @min(run_start, next_start);
                run_end = @max(run_end, @max(glyphEnd(previous, x, y), glyphEnd(current, x, y)));
                x += 1;
            }

            try appendCursorPosition(allocator, &output, y + 1, run_start + 1);
            for (run_start..run_end) |run_x| {
                try appendCell(allocator, &output, current.get(run_x, y).?);
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
    return previous.get(x, y).?.eql(current.get(x, y).?);
}

fn glyphStart(grid: *const cell_grid.CellGrid, x: usize, y: usize) usize {
    const cell = grid.get(x, y).?;
    if (cell.kind == .continuation and x > 0) return x - 1;
    return x;
}

fn glyphEnd(grid: *const cell_grid.CellGrid, x: usize, y: usize) usize {
    const start = glyphStart(grid, x, y);
    const lead = grid.get(start, y).?;
    if (lead.kind == .lead and lead.width == 2) return @min(start + 2, grid.width);
    return @min(start + 1, grid.width);
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

fn appendCell(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    cell: cell_grid.Cell,
) !void {
    switch (cell.kind) {
        .empty => try output.append(allocator, ' '),
        .lead => try output.appendSlice(allocator, cell.grapheme),
        .continuation => {},
    }
}

test "terminal frame redraws every cell-grid row from home" {
    var grid = try cell_grid.CellGrid.init(std.testing.allocator, 4, 2);
    defer grid.deinit();
    try grid.paintUtf8(0, 0, "Hi", 4);
    try grid.paintUtf8(1, 1, "λ", 3);

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

    try current.paintUtf8(1, 0, "AB", 2);
    try current.set(4, 0, 'Z');
    try current.set(0, 1, 'λ');

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

test "terminal diff replaces a wide glyph with narrow text without stale continuation" {
    var previous = try cell_grid.CellGrid.init(std.testing.allocator, 4, 1);
    defer previous.deinit();
    var current = try cell_grid.CellGrid.init(std.testing.allocator, 4, 1);
    defer current.deinit();

    try previous.paintUtf8(0, 0, "界", 4);
    try current.paintUtf8(0, 0, "A", 4);

    const bytes = try encodeDiff(std.testing.allocator, &previous, &current);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1b[1;1HA ", bytes);
}

test "terminal diff never starts inside a wide grapheme" {
    var previous = try cell_grid.CellGrid.init(std.testing.allocator, 4, 1);
    defer previous.deinit();
    var current = try cell_grid.CellGrid.init(std.testing.allocator, 4, 1);
    defer current.deinit();

    try previous.paintUtf8(0, 0, "界", 4);
    try current.paintUtf8(0, 0, "語", 4);

    const bytes = try encodeDiff(std.testing.allocator, &previous, &current);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("\x1b[1;1H語", bytes);
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
