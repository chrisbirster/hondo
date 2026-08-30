const c = @cImport({
    @cInclude("windows.h");
    @cInclude("io.h");
});

pub const SessionError = error{
    NotTerminal,
    InvalidHandle,
    ReadModeFailed,
    EnterRawModeFailed,
    RestoreFailed,
};

pub const Session = struct {
    handle: c.HANDLE,
    original_mode: c.DWORD,
    active: bool = true,

    pub fn begin(fd: c_int) SessionError!Session {
        if (c._isatty(fd) != 1) return SessionError.NotTerminal;
        const os_handle = c._get_osfhandle(fd);
        if (os_handle == -1) return SessionError.InvalidHandle;
        const handle: c.HANDLE = @ptrFromInt(@as(usize, @intCast(os_handle)));

        var original_mode: c.DWORD = 0;
        if (c.GetConsoleMode(handle, &original_mode) == 0) return SessionError.ReadModeFailed;

        var raw_mode = original_mode;
        raw_mode &= ~@as(c.DWORD, c.ENABLE_ECHO_INPUT | c.ENABLE_LINE_INPUT);
        raw_mode |= c.ENABLE_VIRTUAL_TERMINAL_INPUT;
        if (c.SetConsoleMode(handle, raw_mode) == 0) return SessionError.EnterRawModeFailed;

        return .{ .handle = handle, .original_mode = original_mode };
    }

    pub fn restore(self: *Session) SessionError!void {
        if (!self.active) return;
        if (c.SetConsoleMode(self.handle, self.original_mode) == 0) return SessionError.RestoreFailed;
        self.active = false;
    }
};

pub fn isTerminal(fd: c_int) bool {
    return c._isatty(fd) == 1;
}
