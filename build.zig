const std = @import("std");
const ZBuild: type = @import("ZBuild").ZBuild;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    _ = ZBuild.init(.{
        .owner = b,
    });
    const no_update_client = b.option(
        bool,
        "no-update-client",
        "",
    ) orelse false;
    _ = no_update_client;

    const zbuild_dep = b.dependency("ZBuild", .{
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

    const AssetDir = b.option(
        []const u8,
        "AssetDir",
        "Directory for static assets",
    ) orelse "assets";
    const compress = ZBuild.Step.Compress.init(
        b,
        .{ .path = AssetDir },
        "assets",
    );
    compress.method = b.option(
        ZBuild.Step.Compress.Method,
        "compress",
        "which compression method to use in CompressStep",
    ) orelse .Deflate;

    var zb = ZBuild.Step.Serve.init(
        .{
            .owner = b,
            .assets = compress.module(b),
            .dependency = zbuild_dep,
            .name = "serve",
            .options = .{
                .name = "zbuild-serve",
                .root_source_file = .{ .path = "" },
                .target = target,
                .optimize = optimize,
            },
            .api = b.addModule(
                "Api",
                .{
                    .source_file = .{
                        .path = "src/Api.zig",
                    },
                },
            ),
        },
    );
    b.installArtifact(zb.compile);

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
    _ = zb.run(b, run);
    // run.dependOn(&run_step.step);

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
