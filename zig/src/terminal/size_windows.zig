const c = @cImport({
    @cInclude("windows.h");
    @cInclude("io.h");
});

pub const Size = struct {
    width: usize,
    height: usize,
};

pub const SizeError = error{
    NotTerminal,
    InvalidHandle,
    QueryFailed,
    InvalidSize,
};

pub fn query(output_fd: i32) SizeError!Size {
    if (c._isatty(output_fd) != 1) return SizeError.NotTerminal;

    const os_handle = c._get_osfhandle(output_fd);
    if (os_handle == -1) return SizeError.InvalidHandle;
    const handle: c.HANDLE = @ptrFromInt(@as(usize, @intCast(os_handle)));

    var info: c.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (c.GetConsoleScreenBufferInfo(handle, &info) == 0) return SizeError.QueryFailed;

    const width: i32 = @as(i32, info.srWindow.Right) - @as(i32, info.srWindow.Left) + 1;
    const height: i32 = @as(i32, info.srWindow.Bottom) - @as(i32, info.srWindow.Top) + 1;
    if (width <= 0 or height <= 0) return SizeError.InvalidSize;

    return .{
        .width = @intCast(width),
        .height = @intCast(height),
    };
}
