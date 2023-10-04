const std = @import("std");
const CompressStep = @import("src/CompressStep.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
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
        .source_file = .{ .path = "src/CompressStep.zig" },
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

    const server = b.addExecutable(.{
        .name = "zigtty",
        .root_source_file = .{ .path = "src/server.zig" },
        .target = target,
        .optimize = optimize,
    });
    const assets_compressed = CompressStep.init(
        b,
        .{ .path = "src/assets" },
        "assets",
    );
    assets_compressed.compression = b.option(
        CompressStep.Compression,
        "compression",
        "which compression to use in CompressStep",
    ) orelse .Raw;
    server.step.dependOn(&assets_compressed.step);

    const assets = b.addModule("assets", .{
        .source_file = .{
            .generated = &assets_compressed.output_file,
        },
    });
    server.addModule("assets", assets);
    server.addModule("zap", zap.module("zap"));
    server.linkLibrary(zap.artifact("facil.io"));

    const install_server = b.addInstallArtifact(server, .{});
    const update_client = b.addWriteFiles();
    update_client.addCopyFileToSource(client_exe.getEmittedBin(), "src/assets/client.wasm");

    var client = b.step("client", "update client.wasm");
    client.dependOn(&update_client.step);

    var run_server = b.step("run", "run the server");
    if (!no_update_client) server.step.dependOn(client);
    const run_step = b.addRunArtifact(server);
    if (b.args) |args| {
        run_step.addArgs(args);
    }
    run_server.dependOn(&run_step.step);

    var install = b.getInstallStep();
    if (!no_update_client) install.dependOn(client);
    install.dependOn(&install_client.step);
    install.dependOn(&install_server.step);
    // install.dependOn(run_server);

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

const EmbedExeStep = struct {
    content: std.Build.LazyPath,
    compile_step: *std.Build.Step.Compile,
    step: std.Build.Step,

    pub fn create(b: *std.Build, it: *std.Build.Step.Compile) *@This() {
        var readStep = std.Build.Step.init(.{
            .id = .custom,
            .name = "",
            .owner = b,
            .makeFn = make,
        });
        // readStep.dependOn(&it.step);
        var self = b.allocator.create(@This()) catch @panic("OOM");
        self.* = .{
            .step = readStep,
            .compile_step = it,
            .content = .{ .generated = &.{
                .step = &self.*.step,
            } },
        };

        return self;
    }

    pub fn make(step: *std.Build.Step, prog_node: *std.Progress.Node) !void {
        _ = prog_node;
        const self = @fieldParentPtr(
            @This(),
            "step",
            step,
        );
        const b = self.step.owner;
        _ = b;

        // const fs = std.fs.cwd();
        // fs.copyFile(self.compile_step.getEmittedBin(), std.path,.{});

        self.content.path = try std.fs.cwd().readFileAlloc(
            step.owner.allocator,
            self.compile_step.getEmittedBin().getPath(step.owner),
            1048576,
        );
    }

    pub fn deinit(self: @This()) void {
        self.path.deinit();
    }
};

const VendorDependency = struct {
    const Self = @This();
    pub fn init(
        b: *std.Build,
        vendor: bool,
        name: []const u8,
        relative_build_root: []const u8,
        comptime build_zig: type,
        args: anytype,
    ) *std.Build.Dependency {
        return if (vendor)
            b.anonymousDependency(relative_build_root, build_zig, args)
        else
            b.dependency(name, args);
    }
};
