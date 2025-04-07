const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mbl = b.addExecutable(.{
        .name = "mbl",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const repl = b.addExecutable(.{
        .name = "mbl-repl",
        .root_source_file = .{ .path = "src/repl.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(mbl);
    b.installArtifact(repl);

    const run_mbl = b.addRunArtifact(mbl);
    run_mbl.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_mbl.addArgs(args);
    }

    const run_repl = b.addRunArtifact(repl);
    run_repl.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_mbl.step);

    const repl_step = b.step("repl", "Run the REPL");
    repl_step.dependOn(&run_repl.step);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}