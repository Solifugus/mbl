const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Create the MBL interpreter executable
    const exe = b.addExecutable(.{
        .name = "mbl",
        .root_source_file = .{ .path = "mbl_run.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Install the executable to zig-out/bin/
    b.installArtifact(exe);

    // Create a run command for testing the interpreter
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Pass any command line arguments to the executable
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create a run step that can be invoked with `zig build run`
    const run_step = b.step("run", "Run the MBL interpreter");
    run_step.dependOn(&run_cmd.step);

    // Create test steps for individual modules
    const lexer_tests = b.addTest(.{
        .root_source_file = .{ .path = "lexer.zig" },
        .target = target,
        .optimize = optimize,
    });

    const parser_tests = b.addTest(.{
        .root_source_file = .{ .path = "parser.zig" },
        .target = target,
        .optimize = optimize,
    });

    const memory_tests = b.addTest(.{
        .root_source_file = .{ .path = "memory.zig" },
        .target = target,
        .optimize = optimize,
    });

    const interpreter_tests = b.addTest(.{
        .root_source_file = .{ .path = "interpreter.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lexer_tests = b.addRunArtifact(lexer_tests);
    const run_parser_tests = b.addRunArtifact(parser_tests);
    const run_memory_tests = b.addRunArtifact(memory_tests);
    const run_interpreter_tests = b.addRunArtifact(interpreter_tests);

    // Create a test step that runs all tests
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lexer_tests.step);
    test_step.dependOn(&run_parser_tests.step);
    test_step.dependOn(&run_memory_tests.step);
    test_step.dependOn(&run_interpreter_tests.step);
}