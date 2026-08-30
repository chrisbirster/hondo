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
    input_handle: c.HANDLE,
    output_handle: c.HANDLE,
    original_input_mode: c.DWORD,
    original_output_mode: c.DWORD,
    active: bool = true,

    pub fn begin(input_fd: c_int, output_fd: c_int) SessionError!Session {
        if (c._isatty(input_fd) != 1 or c._isatty(output_fd) != 1) return SessionError.NotTerminal;

        const input_os_handle = c._get_osfhandle(input_fd);
        const output_os_handle = c._get_osfhandle(output_fd);
        if (input_os_handle == -1 or output_os_handle == -1) return SessionError.InvalidHandle;

        const input_handle: c.HANDLE = @ptrFromInt(@as(usize, @intCast(input_os_handle)));
        const output_handle: c.HANDLE = @ptrFromInt(@as(usize, @intCast(output_os_handle)));

        var original_input_mode: c.DWORD = 0;
        var original_output_mode: c.DWORD = 0;
        if (c.GetConsoleMode(input_handle, &original_input_mode) == 0) return SessionError.ReadModeFailed;
        if (c.GetConsoleMode(output_handle, &original_output_mode) == 0) return SessionError.ReadModeFailed;

        var raw_input_mode = original_input_mode;
        raw_input_mode &= ~@as(c.DWORD, c.ENABLE_ECHO_INPUT | c.ENABLE_LINE_INPUT | c.ENABLE_PROCESSED_INPUT);
        raw_input_mode |= c.ENABLE_VIRTUAL_TERMINAL_INPUT;
        if (c.SetConsoleMode(input_handle, raw_input_mode) == 0) return SessionError.EnterRawModeFailed;

        const vt_output_mode = original_output_mode | c.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        if (c.SetConsoleMode(output_handle, vt_output_mode) == 0) {
            _ = c.SetConsoleMode(input_handle, original_input_mode);
            return SessionError.EnterRawModeFailed;
        }

        return .{
            .input_handle = input_handle,
            .output_handle = output_handle,
            .original_input_mode = original_input_mode,
            .original_output_mode = original_output_mode,
        };
    }

    pub fn restore(self: *Session) SessionError!void {
        if (!self.active) return;
        self.active = false;

        var failed = false;
        if (c.SetConsoleMode(self.input_handle, self.original_input_mode) == 0) failed = true;
        if (c.SetConsoleMode(self.output_handle, self.original_output_mode) == 0) failed = true;
        if (failed) return SessionError.RestoreFailed;
    }
};

pub fn isTerminal(fd: c_int) bool {
    return c._isatty(fd) == 1;
}
