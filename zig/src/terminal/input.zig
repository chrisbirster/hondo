const std = @import("std");

pub const Key = union(enum) {
    codepoint: u21,
    enter,
    backspace,
    tab,
    shift_tab,
    escape,
    ctrl_a,
    ctrl_b,
    ctrl_c,
    ctrl_d,
    ctrl_e,
    ctrl_f,
    ctrl_g,
    ctrl_h,
    ctrl_i,
    ctrl_j,
    ctrl_k,
    ctrl_l,
    ctrl_m,
    ctrl_n,
    ctrl_o,
    ctrl_p,
    ctrl_q,
    ctrl_r,
    ctrl_s,
    ctrl_t,
    ctrl_u,
    ctrl_v,
    ctrl_w,
    ctrl_x,
    ctrl_y,
    ctrl_z,
    up,
    down,
    left,
    right,
};

pub const MouseButton = enum {
    none,
    left,
    middle,
    right,
    wheel_up,
    wheel_down,
};

pub const MouseAction = enum {
    press,
    release,
    move,
    scroll,
};

pub const MouseEvent = struct {
    x: usize,
    y: usize,
    button: MouseButton,
    action: MouseAction,
    shift: bool = false,
    alt: bool = false,
    ctrl: bool = false,
};

pub const FocusEvent = enum {
    in,
    out,
};

pub const Event = union(enum) {
    key: Key,
    mouse: MouseEvent,
    focus: FocusEvent,
};

pub const Decoded = struct {
    event: Event,
    consumed: usize,
};

pub fn decode(bytes: []const u8) ?Decoded {
    if (bytes.len == 0) return null;

    if (legacyControlKey(bytes[0])) |key| return .{ .event = .{ .key = key }, .consumed = 1 };
    if (bytes[0] == 0x08 or bytes[0] == 0x7f) return .{ .event = .{ .key = .backspace }, .consumed = 1 };
    if (bytes[0] == '\t') return .{ .event = .{ .key = .tab }, .consumed = 1 };
    if (bytes[0] == '\r' or bytes[0] == '\n') return .{ .event = .{ .key = .enter }, .consumed = 1 };

    if (bytes[0] == 0x1b) {
        if (bytes.len >= 3 and bytes[1] == '[') {
            if (bytes[2] == 'I') return .{ .event = .{ .focus = .in }, .consumed = 3 };
            if (bytes[2] == 'O') return .{ .event = .{ .focus = .out }, .consumed = 3 };
            if (bytes[2] == '<') return decodeSgrMouse(bytes);
            if (decodeKittyKey(bytes)) |decoded| return decoded;

            return switch (bytes[2]) {
                'A' => .{ .event = .{ .key = .up }, .consumed = 3 },
                'B' => .{ .event = .{ .key = .down }, .consumed = 3 },
                'C' => .{ .event = .{ .key = .right }, .consumed = 3 },
                'D' => .{ .event = .{ .key = .left }, .consumed = 3 },
                'Z' => .{ .event = .{ .key = .shift_tab }, .consumed = 3 },
                else => .{ .event = .{ .key = .escape }, .consumed = 1 },
            };
        }
        return .{ .event = .{ .key = .escape }, .consumed = 1 };
    }

    const sequence_len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch
        return .{ .event = .{ .key = .{ .codepoint = 0xfffd } }, .consumed = 1 };
    if (bytes.len < sequence_len) return null;
    const codepoint = std.unicode.utf8Decode(bytes[0..sequence_len]) catch 0xfffd;
    return .{ .event = .{ .key = .{ .codepoint = codepoint } }, .consumed = sequence_len };
}

fn legacyControlKey(byte: u8) ?Key {
    return switch (byte) {
        0x01 => .ctrl_a,
        0x02 => .ctrl_b,
        0x03 => .ctrl_c,
        0x04 => .ctrl_d,
        0x05 => .ctrl_e,
        0x06 => .ctrl_f,
        0x07 => .ctrl_g,
        0x0b => .ctrl_k,
        0x0c => .ctrl_l,
        0x0e => .ctrl_n,
        0x0f => .ctrl_o,
        0x10 => .ctrl_p,
        0x11 => .ctrl_q,
        0x12 => .ctrl_r,
        0x13 => .ctrl_s,
        0x14 => .ctrl_t,
        0x15 => .ctrl_u,
        0x16 => .ctrl_v,
        0x17 => .ctrl_w,
        0x18 => .ctrl_x,
        0x19 => .ctrl_y,
        0x1a => .ctrl_z,
        else => null,
    };
}

fn ctrlKeyForCodepoint(codepoint: u21) ?Key {
    const lower = if (codepoint >= 'A' and codepoint <= 'Z') codepoint + ('a' - 'A') else codepoint;
    return switch (lower) {
        'a' => .ctrl_a,
        'b' => .ctrl_b,
        'c' => .ctrl_c,
        'd' => .ctrl_d,
        'e' => .ctrl_e,
        'f' => .ctrl_f,
        'g' => .ctrl_g,
        'h' => .ctrl_h,
        'i' => .ctrl_i,
        'j' => .ctrl_j,
        'k' => .ctrl_k,
        'l' => .ctrl_l,
        'm' => .ctrl_m,
        'n' => .ctrl_n,
        'o' => .ctrl_o,
        'p' => .ctrl_p,
        'q' => .ctrl_q,
        'r' => .ctrl_r,
        's' => .ctrl_s,
        't' => .ctrl_t,
        'u' => .ctrl_u,
        'v' => .ctrl_v,
        'w' => .ctrl_w,
        'x' => .ctrl_x,
        'y' => .ctrl_y,
        'z' => .ctrl_z,
        else => null,
    };
}

fn decodeKittyKey(bytes: []const u8) ?Decoded {
    if (bytes.len < 4 or bytes[0] != 0x1b or bytes[1] != '[') return null;
    var end: ?usize = null;
    var index: usize = 2;
    while (index < bytes.len) : (index += 1) {
        if (bytes[index] == 'u') {
            end = index;
            break;
        }
        if ((bytes[index] < '0' or bytes[index] > '9') and bytes[index] != ';' and bytes[index] != ':') return null;
    }
    const terminator = end orelse return null;
    var parts = std.mem.splitScalar(u8, bytes[2..terminator], ';');
    const code_text = parts.next() orelse return null;
    const mods_text = parts.next() orelse return null;
    const codepoint_u32 = std.fmt.parseInt(u32, code_text, 10) catch return null;
    var mods_parts = std.mem.splitScalar(u8, mods_text, ':');
    const modifier_field = mods_parts.next() orelse return null;
    const encoded_modifiers = std.fmt.parseInt(u16, modifier_field, 10) catch return null;
    if (encoded_modifiers == 0) return null;
    const modifiers = encoded_modifiers - 1;
    if (modifiers & 4 == 0) return null;
    const codepoint = std.math.cast(u21, codepoint_u32) orelse return null;
    const key = ctrlKeyForCodepoint(codepoint) orelse return null;
    return .{ .event = .{ .key = key }, .consumed = terminator + 1 };
}

fn decodeSgrMouse(bytes: []const u8) ?Decoded {
    if (bytes.len < 4) return null;
    var terminator_index: ?usize = null;
    var index: usize = 3;
    while (index < bytes.len) : (index += 1) {
        if (bytes[index] == 'M' or bytes[index] == 'm') {
            terminator_index = index;
            break;
        }
        if ((bytes[index] < '0' or bytes[index] > '9') and bytes[index] != ';') {
            return .{ .event = .{ .key = .escape }, .consumed = 1 };
        }
    }
    const end = terminator_index orelse return null;

    var parts = std.mem.splitScalar(u8, bytes[3..end], ';');
    const code_text = parts.next() orelse return null;
    const x_text = parts.next() orelse return null;
    const y_text = parts.next() orelse return null;
    if (parts.next() != null) return null;

    const code = std.fmt.parseInt(u16, code_text, 10) catch return null;
    const terminal_x = std.fmt.parseInt(usize, x_text, 10) catch return null;
    const terminal_y = std.fmt.parseInt(usize, y_text, 10) catch return null;

    const wheel = code & 64 != 0;
    const motion = code & 32 != 0;
    const base_button = code & 3;
    const release = bytes[end] == 'm';

    const button: MouseButton = if (wheel)
        (if (base_button & 1 == 0) .wheel_up else .wheel_down)
    else switch (base_button) {
        0 => .left,
        1 => .middle,
        2 => .right,
        else => .none,
    };

    const action: MouseAction = if (wheel)
        .scroll
    else if (release)
        .release
    else if (motion)
        .move
    else
        .press;

    return .{
        .event = .{ .mouse = .{
            .x = terminal_x -| 1,
            .y = terminal_y -| 1,
            .button = button,
            .action = action,
            .shift = code & 4 != 0,
            .alt = code & 8 != 0,
            .ctrl = code & 16 != 0,
        } },
        .consumed = end + 1,
    };
}

test "terminal input decodes control navigation and arrow keys" {
    try std.testing.expectEqual(Key.enter, decode("\r").?.event.key);
    try std.testing.expectEqual(Key.backspace, decode("\x08").?.event.key);
    try std.testing.expectEqual(Key.backspace, decode("\x7f").?.event.key);
    try std.testing.expectEqual(Key.tab, decode("\t").?.event.key);
    try std.testing.expectEqual(Key.shift_tab, decode("\x1b[Z").?.event.key);
    try std.testing.expectEqual(Key.escape, decode("\x1b").?.event.key);
    try std.testing.expectEqual(Key.ctrl_c, decode("\x03").?.event.key);
    try std.testing.expectEqual(Key.ctrl_d, decode("\x04").?.event.key);
    try std.testing.expectEqual(Key.ctrl_o, decode("\x0f").?.event.key);
    try std.testing.expectEqual(Key.ctrl_r, decode("\x12").?.event.key);
    try std.testing.expectEqual(Key.ctrl_u, decode("\x15").?.event.key);
    try std.testing.expectEqual(Key.ctrl_v, decode("\x16").?.event.key);
    try std.testing.expectEqual(Key.ctrl_h, decode("\x1b[104;5u").?.event.key);
    try std.testing.expectEqual(Key.ctrl_i, decode("\x1b[105;5u").?.event.key);
    try std.testing.expectEqual(Key.ctrl_j, decode("\x1b[106;5u").?.event.key);
    try std.testing.expectEqual(Key.up, decode("\x1b[A").?.event.key);
    try std.testing.expectEqual(Key.down, decode("\x1b[B").?.event.key);
    try std.testing.expectEqual(Key.left, decode("\x1b[D").?.event.key);
    try std.testing.expectEqual(Key.right, decode("\x1b[C").?.event.key);
}

test "terminal input decodes UTF-8 codepoints" {
    const ascii = decode("x").?;
    try std.testing.expectEqual(@as(u21, 'x'), ascii.event.key.codepoint);
    try std.testing.expectEqual(@as(usize, 1), ascii.consumed);

    const lambda = decode("λ").?;
    try std.testing.expectEqual(@as(u21, 'λ'), lambda.event.key.codepoint);
    try std.testing.expectEqual("λ".len, lambda.consumed);
}

test "terminal input waits for incomplete UTF-8" {
    const bytes = [_]u8{0xce};
    try std.testing.expect(decode(&bytes) == null);
}

test "terminal input decodes SGR mouse press release move scroll and modifiers" {
    const press = decode("\x1b[<0;10;5M").?;
    try std.testing.expectEqual(@as(usize, 9), press.event.mouse.x);
    try std.testing.expectEqual(@as(usize, 4), press.event.mouse.y);
    try std.testing.expectEqual(MouseButton.left, press.event.mouse.button);
    try std.testing.expectEqual(MouseAction.press, press.event.mouse.action);

    const release = decode("\x1b[<0;10;5m").?;
    try std.testing.expectEqual(MouseAction.release, release.event.mouse.action);

    const move = decode("\x1b[<36;3;4M").?;
    try std.testing.expectEqual(MouseAction.move, move.event.mouse.action);
    try std.testing.expect(move.event.mouse.shift);

    const scroll = decode("\x1b[<65;1;1M").?;
    try std.testing.expectEqual(MouseAction.scroll, scroll.event.mouse.action);
    try std.testing.expectEqual(MouseButton.wheel_down, scroll.event.mouse.button);
}

test "terminal input waits for incomplete SGR mouse and decodes focus events" {
    try std.testing.expect(decode("\x1b[<0;2;") == null);
    try std.testing.expectEqual(FocusEvent.in, decode("\x1b[I").?.event.focus);
    try std.testing.expectEqual(FocusEvent.out, decode("\x1b[O").?.event.focus);
}
