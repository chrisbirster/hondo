const c = @cImport({
    @cInclude("windows.h");
    @cInclude("io.h");
});

pub const WaitError = error{
    WaitFailed,
};

pub fn readable(input_fd: i32, timeout_ms: u32) WaitError!bool {
    const os_handle = c._get_osfhandle(input_fd);
    if (os_handle == -1) return WaitError.WaitFailed;
    const handle: c.HANDLE = @ptrFromInt(@as(usize, @intCast(os_handle)));

    const result = c.WaitForSingleObject(handle, @as(c.DWORD, @intCast(timeout_ms)));
    if (result == c.WAIT_OBJECT_0) return true;
    if (result == c.WAIT_TIMEOUT) return false;
    return WaitError.WaitFailed;
}
