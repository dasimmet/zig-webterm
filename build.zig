const std = @import("std");
const MyBuild = @import("src/build/Build.zig");
const zon = @import("build.zig.zon");
const d = zon.dependencies;
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
    _ = no_update_client;

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

    const MyBuildModule = b.addModule("MyBuild", .{
        .source_file = .{ .path = "src/build/Build.zig" },
    });
    _ = MyBuildModule;
    const mybuild_lib = b.addStaticLibrary(.{
        .name = "MyBuild",
        .root_source_file = .{ .path = "src/build/Build.zig" },
        .optimize = optimize,
        .target = target,
    });

    const mime_json = MyBuild.Download.init(
        b,
        .{
            .path = "https://raw.githubusercontent.com/dasimmet/mimetype-io/4a4be597f99080604bab2e5da17a1d44d4f86bc3/src/mimeData.json",
        },
        "mimetypes",
    );
    const mime_zig = MyBuild.JZon.init(
        b,
        .{ .generated = &mime_json.output_file },
        "jzon",
    );
    const mime_mod = mime_zig.module(b);

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
    client_exe.addModule("zap", zap.module("zap"));
    client_exe.addModule("zig-js", zigjs.module("zig-js"));
    const install_client = b.addInstallArtifact(client_exe, .{});
    var docs_dir = client_exe.getEmittedDocs();
    const docs = b.addInstallDirectory(.{
        .source_dir = docs_dir,
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const compress = MyBuild.Compress.init(
        b,
        mybuild_lib.getEmittedDocs(),
        // docs_dir,
        // .{ .path = "assets" },
        "assets",
    );
    compress.method = b.option(
        MyBuild.Compress.Method,
        "compress",
        "which compression method to use in CompressStep",
    ) orelse .Deflate;

    b.step("download", "download").dependOn(&mime_zig.step);

    const exe = b.addExecutable(.{
        .name = "zigtty",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // const docs_dir = exe.getEmittedDocs().relative("index.html");
    // const docs = b.addInstallBinFile(docs_dir, "docs.html");

    exe.addModule("mimetypes", mime_mod);
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

    var run = b.step("run", "run the server");
    // if (!no_update_client) exe.step.dependOn(client);
    const run_step = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_step.addArgs(args);
    }
    run.dependOn(&run_step.step);

    var install_step = b.getInstallStep();
    install_step.dependOn(&install_client.step);
    install_step.dependOn(&install.step);
    install_step.dependOn(&docs.step);

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
