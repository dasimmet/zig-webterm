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

    const emsdk = ZBuild.Step.Emsdk.init(.{
        .name = "emsdk",
        .owner = b,
    });
    const client_exe = b.addSharedLibrary(.{
        .name = "client",
        .root_source_file = .{ .path = "src/client.zig" },
        .target = .{
            .os_tag = .emscripten,
            .cpu_arch = .wasm32,
        },
        .optimize = .ReleaseSmall,
        .use_lld = true,
    });
    client_exe.addSystemFrameworkPath(emsdk.relativePath(
        "upstream/emscripten/cache/sysroot",
    ));
    client_exe.linkLibC();
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
            .port = 8000,
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

    const ptytest = b.addExecutable(.{
        .name = "ptytest",
        .root_source_file = .{ .path = "src/ptytest.zig" },
        .link_libc = true,
    });
    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const ptytest_step = b.step("ptytest", "Run ptytest");
    ptytest_step.dependOn(&b.addRunArtifact(ptytest).step);

    var zig = ZBuild.Step.Sdk.init(.{
        .owner = b,
        .name = "zig",
        .url = .{ .resolved = "https://github.com/ziglang/zig/archive/1b0b46a8a9f5ed3ebaf35e3018fd5402957552ae.tar.gz" },
        .hash = .{ .resolved = "1220ed8db97176353b72d800fe715d0228a591a20236849e374999afbc1fd650b7ea" },
    });
    const zig_exe = b.addExecutable(.{
        .name = "zig-wasm",
        .root_source_file = .{ .path = "src/zig.zig" },
        .target = .{
            .os_tag = .freestanding,
            .cpu_arch = .wasm32,
        },
        .zig_lib_dir = zig.relativePath("lib"),
    });
    const zig_mod = b.addModule("zig", .{
        .source_file = zig.relativePath("src/main.zig"),
    });
    zig_mod.dependencies.put("build_options", b.addModule("build_options", .{
        .source_file = .{ .path = "src/zig_options.zig" },
    })) catch @panic("OOM");
    zig_exe.addModule("zig", zig_mod);
    zig_exe.addModule("fs", compress.module(b));
    const zig_step = b.step("zig", "build zig for wasm");
    zig_step.dependOn(&b.addInstallArtifact(zig_exe, .{}).step);
}
