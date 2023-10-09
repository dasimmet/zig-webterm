//! A `zig build` Step to convert a json file to zig code
//!

pub const JZon = Self;
const Self = @This();
const std = @import("std");
const builtin = @import("builtin");
pub const JsonToZon = @import("../JsonToZon.zig");
pub const JsonToZonLiteral = @embedFile("../JsonToZon.zig");

step: std.build.Step,
source_file: std.build.LazyPath,
output_file: std.Build.GeneratedFile,
max_file_size: usize = 1073741824,

// create a step to convert source_file to output_file
pub fn init(
    b: *std.Build,
    source_file: std.build.LazyPath,
    name: []const u8,
) *Self {
    var step = std.build.Step.init(.{
        .name = name,
        .owner = b,
        .id = std.build.Step.Id.custom,
        .makeFn = make,
    });

    if (source_file == .generated) {
        step.dependOn(source_file.generated.step);
    }
    source_file.addStepDependencies(&step);

    const self: *Self = b.allocator.create(Self) catch {
        @panic("Alloc Error");
    };

    self.* = .{
        .step = step,
        .source_file = source_file,
        .output_file = .{ .step = &self.step },
    };
    return self;
}

// run the build step
fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    const b = step.owner;
    const allocator = b.allocator;
    var self = @fieldParentPtr(
        Self,
        "step",
        step,
    );
    const source_file = self.source_file.getPath2(
        b,
        step,
    );
    const basename = std.fs.path.basename(source_file);
    const out_basename = try std.mem.join(
        allocator,
        "",
        &[_][]const u8{ basename, ".zig" },
    );
    defer allocator.free(out_basename);

    var man = b.cache.obtain();
    defer man.deinit();

    // _ = try man.addFile(
    //     @src().file,
    //     self.max_file_size,
    // );
    // man.hash.addBytes(step.name);
    _ = try man.addFile(source_file, self.max_file_size);
    man.hash.addBytes(JsonToZonLiteral);

    const cached = try man.hit();
    self.step.result_cached = cached;
    const digest = man.final();

    const output_dir = try b.cache_root.join(allocator, &.{
        "o", &digest,
    });
    defer allocator.free(output_dir);

    self.output_file.path = try b.cache_root.join(allocator, &.{
        "o", &digest, out_basename,
    });

    if (cached) {
        return;
    }

    const content = try std.fs.cwd().readFileAlloc(
        allocator,
        source_file,
        self.max_file_size,
    );
    defer allocator.free(content);

    b.cache_root.handle.makeDir("o") catch |err| {
        const trace = @errorReturnTrace();
        _ = trace;
        switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        }
    };

    std.fs.makeDirAbsolute(output_dir) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        }
    };

    const zig_file = try std.fs.createFileAbsolute(
        self.output_file.path.?,
        .{},
    );
    defer zig_file.close();

    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        content,
        .{},
    );
    defer parsed.deinit();

    try JsonToZon.write(
        parsed.value,
        zig_file.writer(),
        4,
    );
}

/// returns a `std.Build.Module` of `output_file`
pub fn module(self: *Self, b: *std.Build) *std.Build.Module {
    return b.addModule(self.step.name, .{
        .source_file = .{
            .generated = &self.output_file,
        },
    });
}
