const std = @import("std");

pub const Key = union(enum) {
    codepoint: u21,
    enter,
    escape,
    ctrl_c,
    up,
    down,
    left,
    right,
};

pub const Decoded = struct {
    key: Key,
    consumed: usize,
};

pub fn decode(bytes: []const u8) ?Decoded {
    if (bytes.len == 0) return null;

    if (bytes[0] == 0x03) return .{ .key = .ctrl_c, .consumed = 1 };
    if (bytes[0] == '\r' or bytes[0] == '\n') return .{ .key = .enter, .consumed = 1 };

    if (bytes[0] == 0x1b) {
        if (bytes.len >= 3 and bytes[1] == '[') {
            return switch (bytes[2]) {
                'A' => .{ .key = .up, .consumed = 3 },
                'B' => .{ .key = .down, .consumed = 3 },
                'C' => .{ .key = .right, .consumed = 3 },
                'D' => .{ .key = .left, .consumed = 3 },
                else => .{ .key = .escape, .consumed = 1 },
            };
        }
        return .{ .key = .escape, .consumed = 1 };
    }

    const sequence_len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch
        return .{ .key = .{ .codepoint = 0xfffd }, .consumed = 1 };
    if (bytes.len < sequence_len) return null;
    const codepoint = std.unicode.utf8Decode(bytes[0..sequence_len]) catch 0xfffd;
    return .{ .key = .{ .codepoint = codepoint }, .consumed = sequence_len };
}

test "terminal input decodes control and arrow keys" {
    try std.testing.expectEqual(Key.enter, decode("\r").?.key);
    try std.testing.expectEqual(Key.escape, decode("\x1b").?.key);
    try std.testing.expectEqual(Key.ctrl_c, decode("\x03").?.key);
    try std.testing.expectEqual(Key.up, decode("\x1b[A").?.key);
    try std.testing.expectEqual(Key.down, decode("\x1b[B").?.key);
    try std.testing.expectEqual(Key.left, decode("\x1b[D").?.key);
    try std.testing.expectEqual(Key.right, decode("\x1b[C").?.key);
}

test "terminal input decodes UTF-8 codepoints" {
    const ascii = decode("x").?;
    try std.testing.expectEqual(@as(u21, 'x'), ascii.key.codepoint);
    try std.testing.expectEqual(@as(usize, 1), ascii.consumed);

    const lambda = decode("λ").?;
    try std.testing.expectEqual(@as(u21, 'λ'), lambda.key.codepoint);
    try std.testing.expectEqual("λ".len, lambda.consumed);
}

test "terminal input waits for incomplete UTF-8" {
    const bytes = [_]u8{0xce};
    try std.testing.expect(decode(&bytes) == null);
}
