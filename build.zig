const std = @import("std");
const zgpu_build = @import("zgpu");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---------------------------------------------------------------
    // Dependencies
    // ---------------------------------------------------------------
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    const zgpu = b.dependency("zgpu", .{
        .target = target,
        .optimize = optimize,
    });
    const zgui = b.dependency("zgui", .{
        .target = target,
        .optimize = optimize,
        .backend = .glfw_wgpu,
    });

    // ---------------------------------------------------------------
    // michel — main app
    // ---------------------------------------------------------------
    const michel = b.addExecutable(.{
        .name = "michel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zgui", .module = zgui.module("root") },
                .{ .name = "zgpu", .module = zgpu.module("root") },
                .{ .name = "zglfw", .module = zglfw.module("root") },
            },
        }),
    });
    michel.linkLibrary(zgui.artifact("imgui"));
    michel.linkLibrary(zgpu.artifact("zdawn"));
    michel.linkLibrary(zglfw.artifact("glfw"));
    zgpu_build.addLibraryPathsTo(michel);

    // C libraries: tinyexr, stb_image, stb_image_write
    michel.addCSourceFiles(.{
        .files = &.{
            "libs/stb_image.c",
            "libs/stb_image_write.c",
            "libs/miniz.c",
        },
        .flags = &.{"-std=c99"},
    });
    michel.addCSourceFiles(.{
        .files = &.{"libs/tinyexr.cpp"},
        .flags = &.{"-std=c++17"},
    });
    michel.addIncludePath(b.path("libs"));
    michel.linkLibC();
    michel.linkLibCpp();

    const install_michel = b.addInstallArtifact(michel, .{});
    b.getInstallStep().dependOn(&install_michel.step);

    const run_michel = b.addRunArtifact(michel);
    run_michel.step.dependOn(&install_michel.step);
    if (b.args) |args| run_michel.addArgs(args);
    const run_step = b.step("run", "Run michel");
    run_step.dependOn(&run_michel.step);

    // ---------------------------------------------------------------
    // michel-cli — headless CLI renderer (no GUI deps)
    // ---------------------------------------------------------------
    const cli = b.addExecutable(.{
        .name = "michel-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zgpu", .module = zgpu.module("root") },
            },
        }),
    });
    cli.linkLibrary(zgpu.artifact("zdawn"));
    zgpu_build.addLibraryPathsTo(cli);

    cli.addCSourceFiles(.{
        .files = &.{
            "libs/stb_image.c",
            "libs/stb_image_write.c",
            "libs/miniz.c",
        },
        .flags = &.{"-std=c99"},
    });
    cli.addCSourceFiles(.{
        .files = &.{"libs/tinyexr.cpp"},
        .flags = &.{"-std=c++17"},
    });
    cli.addIncludePath(b.path("libs"));
    cli.linkLibC();
    cli.linkLibCpp();

    const install_cli = b.addInstallArtifact(cli, .{});
    const cli_step = b.step("cli", "Build the CLI renderer");
    cli_step.dependOn(&install_cli.step);

    const run_cli = b.addRunArtifact(cli);
    run_cli.step.dependOn(&install_cli.step);
    if (b.args) |args| run_cli.addArgs(args);
    const run_cli_step = b.step("run-cli", "Run the CLI renderer");
    run_cli_step.dependOn(&run_cli.step);

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------
    const test_step = b.step("test", "Run unit tests");
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.addCSourceFiles(.{
        .files = &.{
            "libs/stb_image.c",
            "libs/stb_image_write.c",
            "libs/miniz.c",
        },
        .flags = &.{"-std=c99"},
    });
    tests.addCSourceFiles(.{
        .files = &.{"libs/tinyexr.cpp"},
        .flags = &.{"-std=c++17"},
    });
    tests.addIncludePath(b.path("libs"));
    tests.linkLibC();
    tests.linkLibCpp();
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
