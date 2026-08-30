const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const quickjs_source = b.dependency("quickjs_source", .{});

    const quickjs = b.addLibrary(.{
        .name = "quickjs",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    quickjs.root_module.addIncludePath(quickjs_source.path("."));
    quickjs.root_module.addCMacro("_GNU_SOURCE", "1");
    quickjs.root_module.addCMacro("CONFIG_VERSION", "\"2026-06-04\"");
    if (target.result.os.tag == .windows) {
        quickjs.root_module.addCMacro("__USE_MINGW_ANSI_STDIO", "1");
    }
    quickjs.root_module.addCSourceFiles(.{
        .root = quickjs_source.path("."),
        .files = &.{
            "quickjs.c",
            "dtoa.c",
            "libregexp.c",
            "libunicode.c",
            "cutils.c",
        },
        .flags = &.{
            "-fwrapv",
            "-funsigned-char",
            "-Wno-implicit-fallthrough",
            "-Wno-sign-compare",
            "-Wno-missing-field-initializers",
            "-Wno-unused-parameter",
            "-Wno-unused-but-set-variable",
            "-Wno-array-bounds",
            "-Wno-format-truncation",
        },
    });

    const hondo = b.addModule("hondo", .{
        .root_source_file = b.path("zig/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    hondo.addIncludePath(quickjs_source.path("."));
    hondo.linkLibrary(quickjs);

    const unit_tests = b.addTest(.{
        .root_module = hondo,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run Hondo Zig tests");
    test_step.dependOn(&run_unit_tests.step);

    b.default_step = test_step;
}
