const std = @import("std");
const CompressStep = @import("src/build/CompressStep.zig");
const VendorDependency = @import("src/build/VendorDependency.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vendor = b.option(
        bool,
        "vendor",
        "use git submodule for dependencies",
    ) orelse false;
    const no_update_client = b.option(
        bool,
        "no-update-client",
        "",
    ) orelse false;

    const zigjs = VendorDependency.init(
        b,
        vendor,
        "zigjs",
        "libs/zig-js",
        @import("libs/zig-js/build.zig"),
        .{
            .target = target,
            .optimize = optimize,
        },
    );
    const zap = VendorDependency.init(
        b,
        false,
        // vendor, TODO: fix missing dependency issue on facil.io
        "zap",
        "libs/zap",
        @import("libs/zap/build.zig"),
        .{
            .target = target,
            .optimize = optimize,
        },
    );

    const CompressStepModule = b.addModule("CompressStep", .{
        .source_file = .{ .path = "src/build/CompressStep.zig" },
    });
    _ = CompressStepModule;

    const client_exe = b.addSharedLibrary(.{
        .name = "client",
        .root_source_file = .{ .path = "src/client.zig" },
        .target = .{
            .os_tag = .freestanding,
            .cpu_arch = .wasm32,
        },
        .optimize = optimize,
    });
    client_exe.rdynamic = true;
    client_exe.addModule("zig-js", zigjs.module("zig-js"));
    const install_client = b.addInstallArtifact(client_exe, .{});

    const compress = CompressStep.init(
        b,
        .{ .path = "assets" },
        "assets",
    );
    compress.method = b.option(
        CompressStep.Method,
        "compress",
        "which compression method to use in CompressStep",
    ) orelse .Deflate;
    const assets = b.addModule("assets", .{
        .source_file = .{
            .generated = &compress.output_file,
        },
    });

    const exe = b.addExecutable(.{
        .name = "zigtty",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("assets", assets);
    exe.addModule("zap", zap.module("zap"));
    exe.linkLibrary(zap.artifact("facil.io"));
    const install = b.addInstallArtifact(
        exe,
        .{},
    );

    const update_client = b.addWriteFiles();
    update_client.addCopyFileToSource(
        client_exe.getEmittedBin(),
        "assets/client.wasm",
    );
    var client = b.step("client", "update client.wasm");
    client.dependOn(&update_client.step);

    var run = b.step("run", "run the server");
    if (!no_update_client) exe.step.dependOn(client);
    const run_step = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_step.addArgs(args);
    }
    run.dependOn(&run_step.step);

    var install_step = b.getInstallStep();
    install_step.dependOn(&install_client.step);
    install_step.dependOn(&install.step);

    // Creates a step for unit testing.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
