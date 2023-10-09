const std = @import("std");
const ZBuild: type = @import("ZBuild").ZBuild;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_update_client = b.option(
        bool,
        "no-update-client",
        "",
    ) orelse false;
    _ = no_update_client;

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });

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
    // client_exe.addModule("zig-js", zigjs.module("zig-js"));
    const install_client = b.addInstallArtifact(client_exe, .{});

    const compress = ZBuild.Step.Compress.init(
        b,
        .{ .path = "assets" },
        "assets",
    );
    compress.method = b.option(
        ZBuild.Step.Compress.Method,
        "compress",
        "which compression method to use in CompressStep",
    ) orelse compress.method;

    const exe = b.addExecutable(.{
        .name = "zigtty",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // const docs_dir = exe.getEmittedDocs().relative("index.html");
    // const docs = b.addInstallBinFile(docs_dir, "docs.html");

    exe.addModule("assets", compress.assets(b));
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
    client.dependOn(&install_client.step);

    var run = b.step("run", "run the server");
    // if (!no_update_client) exe.step.dependOn(client);
    const run_step = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_step.addArgs(args);
    }
    run.dependOn(&run_step.step);

    var install_step = b.getInstallStep();
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
