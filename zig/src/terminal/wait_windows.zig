const c = @cImport({
    @cInclude("conio.h");
    @cInclude("windows.h");
});

pub const WaitError = error{
    WaitFailed,
};

pub fn readable(input_fd: i32, timeout_ms: u32) WaitError!bool {
    _ = input_fd;
    if (c._kbhit() != 0) return true;
    if (timeout_ms != 0) c.Sleep(timeout_ms);
    return c._kbhit() != 0;
}
