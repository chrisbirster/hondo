const builtin = @import("builtin");

const platform = if (builtin.os.tag == .windows)
    @import("session_windows.zig")
else
    @import("session_posix.zig");

pub const Session = platform.Session;
pub const SessionError = platform.SessionError;
pub const isTerminal = platform.isTerminal;
