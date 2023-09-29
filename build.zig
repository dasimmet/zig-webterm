const std = @import("std");

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

    const vendor = b.option(bool, "vendor", "") orelse false;

    const zigjs = if (vendor)
        b.anonymousDependency("libs/zig-js", @import("libs/zig-js/build.zig"), .{})
    else
        b.dependency("zigjs", .{});

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });

    const client = b.addSharedLibrary(.{
        .name = "client",
        .root_source_file = .{ .path = "src/client.zig" },
        .target = .{
            .os_tag = .freestanding,
            .cpu_arch = .wasm32,
        },
        .optimize = optimize,
    });
    client.rdynamic = true;
    client.addModule("zig-js", zigjs.module("zig-js"));
    const install_client = b.addInstallArtifact(client, .{});

    const server = b.addExecutable(.{
        .name = "server",
        .root_source_file = .{ .path = "src/server.zig" },
        .target = target,
        .optimize = optimize,
    });
    server.addModule("zap", zap.module("zap"));
    server.linkLibrary(zap.artifact("facil.io"));

    const install_server = b.addInstallArtifact(server, .{});
    const update_client = b.addInstallFile(client.getEmittedBin(), "../src/client.wasm");

    var update = b.step("update", "update client.wasm");
    update.dependOn(&update_client.step);

    var run_server = b.step("run", "run the server");
    run_server.dependOn(update);
    run_server.dependOn(&b.addRunArtifact(server).step);

    var install = b.getInstallStep();
    install.dependOn(&install_client.step);
    install.dependOn(&install_server.step);
    install.dependOn(run_server);

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
