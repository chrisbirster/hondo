const std = @import("std");

pub const enter_alternate_screen = "\x1b[?1049h";
pub const leave_alternate_screen = "\x1b[?1049l";
pub const hide_cursor = "\x1b[?25l";
pub const show_cursor = "\x1b[?25h";
pub const home = "\x1b[H";
pub const clear_screen = "\x1b[2J";
pub const reset_style = "\x1b[0m";

pub fn beginSequence(allocator: std.mem.Allocator) ![]u8 {
    return std.mem.concat(allocator, u8, &.{ enter_alternate_screen, hide_cursor, home, clear_screen });
}

pub fn restoreSequence(allocator: std.mem.Allocator) ![]u8 {
    return std.mem.concat(allocator, u8, &.{ reset_style, show_cursor, leave_alternate_screen });
}

test "terminal lifecycle sequences are deterministic" {
    const begin = try beginSequence(std.testing.allocator);
    defer std.testing.allocator.free(begin);
    try std.testing.expectEqualStrings("\x1b[?1049h\x1b[?25l\x1b[H\x1b[2J", begin);

    const restore = try restoreSequence(std.testing.allocator);
    defer std.testing.allocator.free(restore);
    try std.testing.expectEqualStrings("\x1b[0m\x1b[?25h\x1b[?1049l", restore);
}
