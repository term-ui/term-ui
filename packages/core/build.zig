const std = @import("std");

pub fn pipe(steps: anytype) void {
    var prev_step = steps[0];
    inline for (@as([steps.len]*std.Build.Step, steps)[1..]) |step| {
        step.dependOn(prev_step);
        prev_step = step;
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wasm = b.addExecutable(.{
        .name = switch (optimize) {
            .Debug => "core-debug",
            else => "core",
        },
        .root_source_file = b.path("src/wasm.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        }),
        .optimize = optimize,
    });

    wasm.entry = .disabled;
    wasm.export_table = true;
    wasm.rdynamic = true;
    wasm.import_memory = true;

    wasm.import_symbols = true;
    pipe(.{
        &wasm.step,
        &b.addInstallArtifact(wasm, .{}).step,
        b.step("wasm", "Build the wasm executable"),
    });

    const exe = b.addExecutable(.{
        .name = "core",
        .root_source_file = b.path("src/main.zig"),

        // .target = b.resolveTargetQuery(.{
        //     .cpu_arch = .wasm32,
        //     .os_tag = .freestanding,
        // }),
        // .optimize = optimize: {
        //     // Wasm does not support debug info
        //     if (optimize == .Debug) {
        //         break :optimize .ReleaseSmall;
        //     }
        //     break :optimize optimize;
        // },

        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    _ = run_lib_unit_tests; // autofix

    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/wasm.zig"),
        .name = "test",

        .target = target,
        .optimize = optimize,
        .filter = test_filter,
        .test_runner = .{
            .path = b.path("test_runner.zig"),
            .mode = .simple,
        },
    });

    const install_step = b.addInstallArtifact(exe_unit_tests, .{});

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    const test_debugger = b.step("debugbuild", "Run unit tests with debugger");
    test_debugger.dependOn(&install_step.step);
}
