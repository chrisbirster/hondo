const std = @import("std");

const c = @cImport({
    @cInclude("quickjs.h");
});

pub const RuntimeError = error{
    RuntimeCreationFailed,
    ContextCreationFailed,
    EvaluationFailed,
    PendingJobFailed,
};

pub const Runtime = struct {
    runtime: *c.JSRuntime,
    context: *c.JSContext,

    pub fn init() RuntimeError!Runtime {
        const runtime = c.JS_NewRuntime() orelse return RuntimeError.RuntimeCreationFailed;
        errdefer c.JS_FreeRuntime(runtime);

        const context = c.JS_NewContext(runtime) orelse return RuntimeError.ContextCreationFailed;
        c.JS_SetRuntimeInfo(runtime, "hondo-official-quickjs");

        return .{
            .runtime = runtime,
            .context = context,
        };
    }

    pub fn deinit(self: *Runtime) void {
        c.JS_FreeContext(self.context);
        c.JS_FreeRuntime(self.runtime);
        self.* = undefined;
    }

    pub fn eval(self: *Runtime, source: []const u8, filename: [*:0]const u8) RuntimeError!void {
        const value = c.JS_Eval(
            self.context,
            source.ptr,
            source.len,
            filename,
            c.JS_EVAL_TYPE_GLOBAL,
        );
        defer c.JS_FreeValue(self.context, value);

        if (c.JS_IsException(value) != 0) {
            dumpException(self.context);
            return RuntimeError.EvaluationFailed;
        }

        try self.drainJobs();
    }

    pub fn drainJobs(self: *Runtime) RuntimeError!void {
        while (c.JS_IsJobPending(self.runtime) != 0) {
            var job_context: ?*c.JSContext = null;
            if (c.JS_ExecutePendingJob(self.runtime, &job_context) < 0) {
                dumpException(job_context orelse self.context);
                return RuntimeError.PendingJobFailed;
            }
        }
    }
};

fn dumpException(context: *c.JSContext) void {
    const exception = c.JS_GetException(context);
    defer c.JS_FreeValue(context, exception);

    const message = c.JS_ToCString(context, exception);
    if (message == null) return;
    defer c.JS_FreeCString(context, message);

    const zero_terminated: [*:0]const u8 = @ptrCast(message);
    std.debug.print("Hondo QuickJS exception: {s}\n", .{std.mem.span(zero_terminated)});
}

test "QuickJS evaluates JavaScript in the Zig runtime" {
    var runtime = try Runtime.init();
    defer runtime.deinit();

    try runtime.eval(
        "globalThis.__hondoSmoke = 40 + 2;",
        "hondo-smoke.js",
    );
    try runtime.eval(
        "if (globalThis.__hondoSmoke !== 42) throw new Error('wrong result');",
        "hondo-smoke-verify.js",
    );
}

test "QuickJS drains Promise jobs" {
    var runtime = try Runtime.init();
    defer runtime.deinit();

    try runtime.eval(
        \\globalThis.__hondoPromise = 0;
        \\Promise.resolve(42).then(value => { globalThis.__hondoPromise = value; });
    , "hondo-promise.js");
    try runtime.eval(
        "if (globalThis.__hondoPromise !== 42) throw new Error('pending job did not run');",
        "hondo-promise-verify.js",
    );
}

test "QuickJS reports evaluation failures" {
    var runtime = try Runtime.init();
    defer runtime.deinit();

    try std.testing.expectError(
        RuntimeError.EvaluationFailed,
        runtime.eval("throw new Error('expected smoke failure');", "hondo-error.js"),
    );
}
