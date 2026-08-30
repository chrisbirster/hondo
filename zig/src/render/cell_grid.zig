const std = @import("std");

pub const GridError = error{
    DimensionMismatch,
};

pub const Cell = struct {
    codepoint: u21 = ' ',
};

pub const CellGrid = struct {
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,
    cells: []Cell,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !CellGrid {
        const cells = try allocator.alloc(Cell, width * height);
        @memset(cells, Cell{});
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .cells = cells,
        };
    }

    pub fn deinit(self: *CellGrid) void {
        self.allocator.free(self.cells);
        self.* = undefined;
    }

    pub fn clear(self: *CellGrid) void {
        @memset(self.cells, Cell{});
    }

    pub fn sameDimensions(self: *const CellGrid, other: *const CellGrid) bool {
        return self.width == other.width and self.height == other.height;
    }

    pub fn copyFrom(self: *CellGrid, other: *const CellGrid) GridError!void {
        if (!self.sameDimensions(other)) return GridError.DimensionMismatch;
        @memcpy(self.cells, other.cells);
    }

    pub fn set(self: *CellGrid, x: usize, y: usize, codepoint: u21) void {
        if (x >= self.width or y >= self.height) return;
        self.cells[y * self.width + x].codepoint = codepoint;
    }

    pub fn get(self: *const CellGrid, x: usize, y: usize) ?Cell {
        if (x >= self.width or y >= self.height) return null;
        return self.cells[y * self.width + x];
    }

    pub fn paintUtf8(self: *CellGrid, start_x: usize, y: usize, text: []const u8, max_width: usize) void {
        if (y >= self.height or start_x >= self.width or max_width == 0) return;

        var byte_index: usize = 0;
        var column: usize = 0;
        while (byte_index < text.len and column < max_width and start_x + column < self.width) {
            const sequence_len = std.unicode.utf8ByteSequenceLength(text[byte_index]) catch {
                byte_index += 1;
                self.set(start_x + column, y, 0xfffd);
                column += 1;
                continue;
            };
            const end = byte_index + sequence_len;
            if (end > text.len) {
                self.set(start_x + column, y, 0xfffd);
                break;
            }
            const codepoint = std.unicode.utf8Decode(text[byte_index..end]) catch 0xfffd;
            self.set(start_x + column, y, codepoint);
            byte_index = end;
            column += 1;
        }
    }

    pub fn rowUtf8(self: *const CellGrid, allocator: std.mem.Allocator, y: usize) ![]u8 {
        if (y >= self.height) return allocator.dupe(u8, "");

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);

        for (0..self.width) |x| {
            const codepoint = self.cells[y * self.width + x].codepoint;
            var buffer: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(codepoint, &buffer) catch {
                try output.appendSlice(allocator, "�");
                continue;
            };
            try output.appendSlice(allocator, buffer[0..len]);
        }

        return output.toOwnedSlice(allocator);
    }
};

test "cell grid paints UTF-8 and clips at the grid boundary" {
    var grid = try CellGrid.init(std.testing.allocator, 5, 2);
    defer grid.deinit();

    grid.paintUtf8(1, 0, "AλBCDE", 4);

    const row = try grid.rowUtf8(std.testing.allocator, 0);
    defer std.testing.allocator.free(row);
    try std.testing.expectEqualStrings(" AλBC", row);
}

test "cell grid ignores writes outside its bounds" {
    var grid = try CellGrid.init(std.testing.allocator, 2, 1);
    defer grid.deinit();

    grid.set(99, 99, 'x');
    try std.testing.expectEqual(@as(u21, ' '), grid.get(0, 0).?.codepoint);
}

test "cell grid copies matching frames and rejects mismatched dimensions" {
    var source = try CellGrid.init(std.testing.allocator, 3, 1);
    defer source.deinit();
    source.paintUtf8(0, 0, "Aλ", 3);

    var destination = try CellGrid.init(std.testing.allocator, 3, 1);
    defer destination.deinit();
    try destination.copyFrom(&source);

    const row = try destination.rowUtf8(std.testing.allocator, 0);
    defer std.testing.allocator.free(row);
    try std.testing.expectEqualStrings("Aλ ", row);

    var mismatched = try CellGrid.init(std.testing.allocator, 2, 1);
    defer mismatched.deinit();
    try std.testing.expectError(GridError.DimensionMismatch, mismatched.copyFrom(&source));
}
