const std = @import("std");
const builtin = @import("builtin");
pub const CompressStep = @import("CompressStep.zig");

step: std.build.Step,
dir: std.build.LazyPath,
compress: *CompressStep,
compile: *std.Build.CompileStep,
run: *std.Build.RunStep,

const ServeStep = @This();

pub fn init(
    b: *std.Build,
    dir: std.build.LazyPath,
    name: []const u8,
    opt: std.build.ExecutableOptions,
) ServeStep {
    var step = std.build.Step.init(.{
        .name = name,
        .owner = b,
        .id = std.build.Step.Id.run,
        .makeFn = make,
    });

    const self: *CompressStep = b.allocator.create(CompressStep) catch {
        @panic("Alloc Error");
    };
    const exe = b.addExecutable(opt);

    self.* = .{
        .step = step,
        .compress = CompressStep.init(b, dir, name),
        .compile = exe,
        .run = b.addRunArtifact(exe),
    };
    return self;
}

fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    const b = step.owner;
    var serve = @fieldParentPtr(
        ServeStep,
        "step",
        step,
    );
    var man = b.cache.obtain();
    defer man.deinit();
    man.hash.addBytes(step.name);
    man.hash.addBytes(serve.dir.path);
}
