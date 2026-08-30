const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const quickjs_source = b.dependency("quickjs_source", .{});
    const is_windows = target.result.os.tag == .windows;

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
    if (is_windows) {
        quickjs.root_module.addCMacro("__USE_MINGW_ANSI_STDIO", "1");
    }

    const quickjs_c_flags = &.{
        "-fwrapv",
        "-funsigned-char",
        "-Wno-implicit-fallthrough",
        "-Wno-sign-compare",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-but-set-variable",
        "-Wno-array-bounds",
        "-Wno-format-truncation",
    };

    quickjs.root_module.addCSourceFiles(.{
        .root = quickjs_source.path("."),
        .files = &.{
            "dtoa.c",
            "libregexp.c",
            "libunicode.c",
            "cutils.c",
        },
        .flags = quickjs_c_flags,
    });

    if (is_windows) {
        quickjs.root_module.addCSourceFiles(.{
            .root = b.path("."),
            .files = &.{"zig/c/quickjs_windows.c"},
            .flags = quickjs_c_flags,
        });
    } else {
        quickjs.root_module.addCSourceFiles(.{
            .root = quickjs_source.path("."),
            .files = &.{"quickjs.c"},
            .flags = quickjs_c_flags,
        });
    }

    const build_counter_bundle = b.addSystemCommand(&.{
        "node",
        "node_modules/esbuild/bin/esbuild",
        "examples/counter/src/bundle.ts",
        "--bundle",
        "--platform=neutral",
        "--format=iife",
        "--target=es2020",
        "--conditions=browser,development",
        "--outfile=zig/src/generated/counter.js",
    });

    const js_step = b.step("js", "Build Hondo JavaScript bundles for the embedded runtime");
    js_step.dependOn(&build_counter_bundle.step);

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
    unit_tests.step.dependOn(&build_counter_bundle.step);
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run Hondo Zig tests");
    test_step.dependOn(&run_unit_tests.step);

    b.default_step = test_step;
}
