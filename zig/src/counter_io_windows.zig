const c = @cImport({
    @cInclude("io.h");
});

pub const IoError = error{
    ReadFailed,
    WriteFailed,
};

pub fn readByte(fd: c_int) IoError!?u8 {
    var byte: u8 = 0;
    const result = c._read(fd, &byte, 1);
    if (result == 1) return byte;
    if (result == 0) return null;
    return IoError.ReadFailed;
}

pub fn writeAll(fd: c_int, bytes: []const u8) IoError!void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const remaining = bytes.len - offset;
        const chunk: c_uint = @intCast(@min(remaining, std.math.maxInt(c_uint)));
        const result = c._write(fd, bytes.ptr + offset, chunk);
        if (result <= 0) return IoError.WriteFailed;
        offset += @intCast(result);
    }
}

const std = @import("std");
