const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

pub const SessionError = error{
    NotTerminal,
    ReadAttributesFailed,
    EnterRawModeFailed,
    RestoreFailed,
};

pub const Session = struct {
    fd: c_int,
    original: c.struct_termios,
    active: bool = true,

    pub fn begin(fd: c_int) SessionError!Session {
        if (c.isatty(fd) != 1) return SessionError.NotTerminal;

        var original: c.struct_termios = undefined;
        if (c.tcgetattr(fd, &original) != 0) return SessionError.ReadAttributesFailed;

        var raw = original;
        c.cfmakeraw(&raw);
        if (c.tcsetattr(fd, c.TCSAFLUSH, &raw) != 0) return SessionError.EnterRawModeFailed;

        return .{
            .fd = fd,
            .original = original,
        };
    }

    pub fn restore(self: *Session) SessionError!void {
        if (!self.active) return;
        if (c.tcsetattr(self.fd, c.TCSAFLUSH, &self.original) != 0) {
            return SessionError.RestoreFailed;
        }
        self.active = false;
    }
};

pub fn isTerminal(fd: c_int) bool {
    return c.isatty(fd) == 1;
}
