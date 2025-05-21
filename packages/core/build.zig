const std = @import("std");
fn getIcuHeadersDir(b: *std.Build) ![]const u8 {
    const headers_dir = std.mem.trim(u8, (try std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{
            "sh",
            "-c",
            "cargo metadata --format-version 1 | jq '.packages[] | select(.name == \"icu_capi\").manifest_path' | xargs dirname",
        },
    })).stdout, " \n\r");
    const cwd = b.build_root.path orelse unreachable;
    var headers_dir_path = try std.fs.path.relative(b.allocator, cwd, headers_dir);
    headers_dir_path = try std.fs.path.join(b.allocator, &.{ headers_dir_path, "bindings", "c" });
    return headers_dir_path;
}
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
    const headers_dir_path = try getIcuHeadersDir(b);

    _ = headers_dir_path; // autofix
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
    wasm.linkLibC();
    // wasm.addLibraryPath(b.path("./target/wasm32-unknown-unknown/release"));
    // wasm.addIncludePath(b.path(headers_dir_path));
    // wasm.linkSystemLibrary("icu_capi");

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

    // exe.import_symbols = true;
    // exe.dead_strip_dylibs = true;
    // exe.
    // zig  c++ -std=c++17 -L target/release -I /Users/juliaortiz/.cargo/registry/src/index.crates.io-6f17d22bba15001f/icu_capi-1.5.0/bindings/cpp segmenter.cpp -licu_capi -lm -o segmenter && ./segmenter
    // exe.linkLibCpp();

    // exe.entry = .disabled;
    // exe.export_table = true;
    // exe.rdynamic = true;
    // exe.import_memory = true;
    // exe.
    exe.linkLibC();

    // exe.addIncludePath(b.path(headers_dir_path));

    // exe.addIncludePath(b.path("../../../.cargo/registry/src/index.crates.io-6f17d22bba15001f/icu_capi-1.5.0/bindings/c"));
    // exe.addLibraryPath(b.path("./target/release"));

    // exe.linkSystemLibrary("icu_capi");
    // exe.linkSystemLibrary("m");
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
    // std.debug.print("target: {any}\n", .{target});

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    _ = run_lib_unit_tests; // autofix

    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    var escaped_filter: ?[]const u8 = null;
    if (test_filter) |filter| {
        escaped_filter = try std.mem.replaceOwned(u8, b.allocator, filter, " ", "%20");
    }

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/wasm.zig"),
        .name = "test",

        .target = target,
        .optimize = optimize,
        // .filters = test_filters,
        .filter = escaped_filter,
        .test_runner = .{
            .path = b.path("test_runner.zig"),
            .mode = .simple,
        },
    });

    // exe_unit_tests.linkLibC();
    // exe_unit_tests.addIncludePath(b.path(headers_dir_path));
    // exe_unit_tests.addLibraryPath(b.path("./target/release"));

    // exe_unit_tests.linkSystemLibrary("icu_capi");

    const install_step = b.addInstallArtifact(exe_unit_tests, .{});

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    const test_debugger = b.step("debugbuild", "Run unit tests with debugger");
    test_debugger.dependOn(&install_step.step);

    // Add gradient performance demo executable
    const gradient_perf_exe = b.addExecutable(.{
        .name = "gradient_perf",
        .root_source_file = b.path("src/gradient_perf.zig"),
        .target = target,
        .optimize = optimize,
    });

    // gradient_perf_exe.linkLibC();
    // gradient_perf_exe.addIncludePath(b.path(headers_dir_path));
    // gradient_perf_exe.addLibraryPath(b.path("./target/release"));
    // gradient_perf_exe.linkSystemLibrary("icu_capi");

    b.installArtifact(gradient_perf_exe);

    const run_gradient_perf = b.addRunArtifact(gradient_perf_exe);
    run_gradient_perf.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_gradient_perf.addArgs(args);
    }

    const gradient_perf_step = b.step("gradient-perf", "Run the gradient performance demo");
    gradient_perf_step.dependOn(&run_gradient_perf.step);

    // Interactive gradient demo executable
    const gradient_interactive_exe = b.addExecutable(.{
        .name = "gradient_interactive",
        .root_source_file = b.path("src/gradient_interactive.zig"),
        .target = target,
        .optimize = optimize,
    });

    // gradient_interactive_exe.linkLibC();
    // gradient_interactive_exe.addIncludePath(b.path(headers_dir_path));
    // gradient_interactive_exe.addLibraryPath(b.path("./target/release"));
    // gradient_interactive_exe.linkSystemLibrary("icu_capi");

    b.installArtifact(gradient_interactive_exe);

    const run_gradient_interactive = b.addRunArtifact(gradient_interactive_exe);
    run_gradient_interactive.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_gradient_interactive.addArgs(args);
    }

    const gradient_interactive_step = b.step("gradient-interactive", "Run the interactive gradient demo");
    gradient_interactive_step.dependOn(&run_gradient_interactive.step);
}
