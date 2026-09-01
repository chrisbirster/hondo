from pathlib import Path

def repl(path, old, new, label):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'missing {label} in {path}')
    if s.count(old) != 1:
        raise SystemExit(f'non-unique {label} in {path}: {s.count(old)}')
    p.write_text(s.replace(old, new, 1))

ctrl_tags = '\n'.join(f'    ctrl_{chr(ord("a")+i)},' for i in range(26))
repl('zig/src/terminal/input.zig', '    escape,\n    ctrl_c,\n    up,\n', f'    escape,\n{ctrl_tags}\n    up,\n', 'ctrl key union')
repl('zig/src/terminal/input.zig', '    if (bytes[0] == 0x03) return .{ .event = .{ .key = .ctrl_c }, .consumed = 1 };\n    if (bytes[0] == 0x08 or bytes[0] == 0x7f) return .{ .event = .{ .key = .backspace }, .consumed = 1 };\n', '    if (legacyControlKey(bytes[0])) |key| return .{ .event = .{ .key = key }, .consumed = 1 };\n    if (bytes[0] == 0x08 or bytes[0] == 0x7f) return .{ .event = .{ .key = .backspace }, .consumed = 1 };\n', 'legacy ctrl decode')
repl('zig/src/terminal/input.zig', "            if (bytes[2] == 'I') return .{ .event = .{ .focus = .in }, .consumed = 3 };\n            if (bytes[2] == 'O') return .{ .event = .{ .focus = .out }, .consumed = 3 };\n            if (bytes[2] == '<') return decodeSgrMouse(bytes);\n\n            return switch (bytes[2]) {\n", "            if (bytes[2] == 'I') return .{ .event = .{ .focus = .in }, .consumed = 3 };\n            if (bytes[2] == 'O') return .{ .event = .{ .focus = .out }, .consumed = 3 };\n            if (bytes[2] == '<') return decodeSgrMouse(bytes);\n            if (decodeKittyKey(bytes)) |decoded| return decoded;\n\n            return switch (bytes[2]) {\n", 'kitty hook')

p = Path('zig/src/terminal/input.zig')
s = p.read_text()
anchor = 'fn decodeSgrMouse(bytes: []const u8) ?Decoded {'
helpers = r'''fn legacyControlKey(byte: u8) ?Key {
    return switch (byte) {
        0x01 => .ctrl_a, 0x02 => .ctrl_b, 0x03 => .ctrl_c, 0x04 => .ctrl_d,
        0x05 => .ctrl_e, 0x06 => .ctrl_f, 0x07 => .ctrl_g,
        0x0b => .ctrl_k, 0x0c => .ctrl_l, 0x0e => .ctrl_n, 0x0f => .ctrl_o,
        0x10 => .ctrl_p, 0x11 => .ctrl_q, 0x12 => .ctrl_r, 0x13 => .ctrl_s,
        0x14 => .ctrl_t, 0x15 => .ctrl_u, 0x16 => .ctrl_v, 0x17 => .ctrl_w,
        0x18 => .ctrl_x, 0x19 => .ctrl_y, 0x1a => .ctrl_z,
        else => null,
    };
}

fn ctrlKeyForCodepoint(codepoint: u21) ?Key {
    const lower = if (codepoint >= 'A' and codepoint <= 'Z') codepoint + ('a' - 'A') else codepoint;
    return switch (lower) {
        'a' => .ctrl_a, 'b' => .ctrl_b, 'c' => .ctrl_c, 'd' => .ctrl_d,
        'e' => .ctrl_e, 'f' => .ctrl_f, 'g' => .ctrl_g, 'h' => .ctrl_h,
        'i' => .ctrl_i, 'j' => .ctrl_j, 'k' => .ctrl_k, 'l' => .ctrl_l,
        'm' => .ctrl_m, 'n' => .ctrl_n, 'o' => .ctrl_o, 'p' => .ctrl_p,
        'q' => .ctrl_q, 'r' => .ctrl_r, 's' => .ctrl_s, 't' => .ctrl_t,
        'u' => .ctrl_u, 'v' => .ctrl_v, 'w' => .ctrl_w, 'x' => .ctrl_x,
        'y' => .ctrl_y, 'z' => .ctrl_z,
        else => null,
    };
}

fn decodeKittyKey(bytes: []const u8) ?Decoded {
    if (bytes.len < 4 or bytes[0] != 0x1b or bytes[1] != '[') return null;
    var end: ?usize = null;
    var index: usize = 2;
    while (index < bytes.len) : (index += 1) {
        if (bytes[index] == 'u') { end = index; break; }
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

'''
if anchor not in s: raise SystemExit('missing sgr anchor')
p.write_text(s.replace(anchor, helpers + anchor, 1))

p = Path('zig/src/terminal/input.zig')
s = p.read_text()
old = '    try std.testing.expectEqual(Key.ctrl_c, decode("\\x03").?.event.key);\n    try std.testing.expectEqual(Key.up, decode("\\x1b[A").?.event.key);\n'
new = '    try std.testing.expectEqual(Key.ctrl_c, decode("\\x03").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_d, decode("\\x04").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_o, decode("\\x0f").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_r, decode("\\x12").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_u, decode("\\x15").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_v, decode("\\x16").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_h, decode("\\x1b[104;5u").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_i, decode("\\x1b[105;5u").?.event.key);\n    try std.testing.expectEqual(Key.ctrl_j, decode("\\x1b[106;5u").?.event.key);\n    try std.testing.expectEqual(Key.up, decode("\\x1b[A").?.event.key);\n'
if old not in s: raise SystemExit('missing input test anchor')
p.write_text(s.replace(old, new, 1))

repl('zig/src/terminal/control.zig', 'pub const enable_focus_events = "\\x1b[?1004h";\npub const disable_focus_events = "\\x1b[?1004l";\n', 'pub const enable_focus_events = "\\x1b[?1004h";\npub const disable_focus_events = "\\x1b[?1004l";\npub const enable_keyboard_disambiguation = "\\x1b[>1u";\npub const disable_keyboard_disambiguation = "\\x1b[<u";\n', 'keyboard protocol constants')
repl('zig/src/terminal/control.zig', '    return std.mem.concat(allocator, u8, &.{ enable_mouse_buttons, enable_sgr_mouse, enable_focus_events });\n', '    return std.mem.concat(allocator, u8, &.{ enable_mouse_buttons, enable_sgr_mouse, enable_focus_events, enable_keyboard_disambiguation });\n', 'input begin sequence')
repl('zig/src/terminal/control.zig', '    return std.mem.concat(allocator, u8, &.{ disable_focus_events, disable_sgr_mouse, disable_mouse_buttons });\n', '    return std.mem.concat(allocator, u8, &.{ disable_keyboard_disambiguation, disable_focus_events, disable_sgr_mouse, disable_mouse_buttons });\n', 'input restore sequence')
repl('zig/src/terminal/control.zig', '    try std.testing.expectEqualStrings("\\x1b[?1000h\\x1b[?1006h\\x1b[?1004h", begin);\n\n    const restore = try inputFeaturesRestoreSequence(std.testing.allocator);\n    defer std.testing.allocator.free(restore);\n    try std.testing.expectEqualStrings("\\x1b[?1004l\\x1b[?1006l\\x1b[?1000l", restore);\n', '    try std.testing.expectEqualStrings("\\x1b[?1000h\\x1b[?1006h\\x1b[?1004h\\x1b[>1u", begin);\n\n    const restore = try inputFeaturesRestoreSequence(std.testing.allocator);\n    defer std.testing.allocator.free(restore);\n    try std.testing.expectEqualStrings("\\x1b[<u\\x1b[?1004l\\x1b[?1006l\\x1b[?1000l", restore);\n', 'control tests')

p = Path('zig/src/runtime/input_events.zig')
s = p.read_text()
old = '        .ctrl_c => .{ .event_type = "key", .payload = "{\\"kind\\":\\"ctrlC\\"}" },\n'
if old not in s: raise SystemExit('missing encode ctrl_c')
cases = ''.join(f'        .ctrl_{chr(97+i)} => .{{ .event_type = "key", .payload = "{{\\"kind\\":\\"ctrl{chr(65+i)}\\"}}" }},\n' for i in range(26))
s = s.replace(old, cases, 1)
needle = '    const shift_tab = try encode(std.testing.allocator, .{ .key = .shift_tab });\n    try std.testing.expectEqualStrings("{\\"kind\\":\\"shiftTab\\"}", shift_tab.payload);\n'
replacement = needle + '\n    const ctrl_o = try encode(std.testing.allocator, .{ .key = .ctrl_o });\n    try std.testing.expectEqualStrings("{\\"kind\\":\\"ctrlO\\"}", ctrl_o.payload);\n    const ctrl_i = try encode(std.testing.allocator, .{ .key = .ctrl_i });\n    try std.testing.expectEqualStrings("{\\"kind\\":\\"ctrlI\\"}", ctrl_i.payload);\n'
if needle not in s: raise SystemExit('missing input_events test anchor')
p.write_text(s.replace(needle, replacement, 1))

print('full ctrl-key vocabulary applied')
