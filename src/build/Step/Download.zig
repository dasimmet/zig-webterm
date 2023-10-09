const std = @import("std");
const builtin = @import("builtin");

step: std.build.Step,
url: std.build.LazyPath,
output_dir: std.Build.GeneratedFile,
output_file: std.Build.GeneratedFile,
max_file_size: usize = 1073741824,

const DownloadStep = @This();
const Self = DownloadStep;

pub fn init(
    b: *std.Build,
    url: std.build.LazyPath,
    name: []const u8,
) *Self {
    var step = std.build.Step.init(.{
        .name = name,
        .owner = b,
        .id = std.build.Step.Id.custom,
        .makeFn = make,
    });

    url.addStepDependencies(&step);

    const self: *@This() = b.allocator.create(@This()) catch {
        @panic("Alloc Error");
    };

    self.* = .{
        .step = step,
        .url = url,
        .output_dir = .{ .step = &self.step },
        .output_file = .{ .step = &self.step },
    };
    return self;
}

fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    const b = step.owner;
    const allocator = b.allocator;
    var self = @fieldParentPtr(
        Self,
        "step",
        step,
    );
    const url = self.url.path;

    var man = b.cache.obtain();
    defer man.deinit();

    // _ = try man.addFile(
    //     @src().file,
    //     self.max_file_size,
    // );
    // man.hash.addBytes(step.name);
    man.hash.addBytes(url);

    const basename = std.fs.path.basename(url);
    // std.log.warn("Basename: {s}", .{basename});

    self.step.result_cached = try man.hit();
    const digest = man.final();

    self.output_dir.path = try b.global_cache_root.join(allocator, &.{
        "o", &digest,
    });

    self.output_file.path = try b.global_cache_root.join(allocator, &.{
        "o", &digest, basename,
    });
    // std.log.warn("out: {s}", .{self.output_file.path.?});

    b.global_cache_root.handle.makeDir("o") catch |err| {
        const trace = @errorReturnTrace();
        _ = trace;
        switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        }
    };

    std.fs.makeDirAbsolute(self.output_dir.path.?) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        }
    };

    if (!self.step.result_cached) {
        b.global_cache_root.handle.makeDir("tmp") catch |err| {
            switch (err) {
                error.PathAlreadyExists => {},
                else => |e| return e,
            }
        };

        const dl_dir = try b.global_cache_root.join(
            allocator,
            &.{
                "tmp", &digest,
            },
        );
        defer allocator.free(dl_dir);

        const dl_file = try b.global_cache_root.join(
            allocator,
            &.{
                "tmp", &digest, basename,
            },
        );
        defer allocator.free(dl_file);

        // const cwd = std.fs.cwd();
        try std.fs.makeDirAbsolute(dl_dir);
        defer std.fs.deleteTreeAbsolute(dl_dir) catch {
            std.log.err("Error Cleaning Dir: {s}", .{dl_dir});
            @panic("Directory Cleanup");
        };

        const argv = [_][]const u8{ "curl", "-OL", url };
        const cmd = try std.mem.join(b.allocator, " ", &argv);
        defer allocator.free(cmd);

        var proc = try std.ChildProcess.exec(.{
            .allocator = allocator,
            .argv = &argv,
            .max_output_bytes = self.max_file_size,
            .cwd = dl_dir,
        });
        defer allocator.free(proc.stderr);
        defer allocator.free(proc.stdout);

        if (proc.term != .Exited or proc.term.Exited != 0) {
            std.log.err(
                "Proc error: {s}\nTerm:{any}\nStderr:\n{s}\nStdout:\n{s}",
                .{ cmd, proc.term, proc.stderr, proc.stdout },
            );
            return error.ChildProcess;
        }
        std.fs.renameAbsolute(
            dl_file,
            self.output_file.path.?,
        ) catch |err| {
            std.log.err("Error renaming File: {s}", .{dl_file});
            return err;
        };
        try man.writeManifest();
    }
}
