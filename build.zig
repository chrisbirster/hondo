const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const hondo = b.addModule("hondo", .{
        .root_source_file = b.path("zig/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .root_module = hondo,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run Hondo Zig tests");
    test_step.dependOn(&run_unit_tests.step);

    b.default_step = test_step;
}
