const std = @import("std");

step: std.build.Step,
dir: std.build.LazyPath,
output_file: std.Build.GeneratedFile,
fd: std.fs.File = undefined,

const CompressStep = @This();

pub fn init(
    b: *std.Build,
    dir: std.build.LazyPath,
    name: []const u8,
) *CompressStep {
    var step = std.build.Step.init(.{
        .name = name,
        .owner = b,
        .id = std.build.Step.Id.custom,
        .makeFn = make,
    });

    const self: *CompressStep = b.allocator.create(CompressStep) catch {
        @panic("Alloc Error");
    };
    self.* = .{
        .step = step,
        .dir = dir,
        .output_file = .{ .step = &self.step },
    };
    return self;
}

const prefix =
    \\// a map of path on the server to the embedded response
    \\const std = @import("std");
    \\const Compression = enum{
    \\  Raw,
    \\  Gzip,
    \\};
    \\const Entry = struct{
    \\    body: []const u8,
    \\    compression: Compression,
    \\};
    \\pub const map = std.ComptimeStringMap(
    \\    []const u8,
    \\    [_]struct{[]const u8,Entry}{
    \\
;
const suffix = "});\n";

fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
    var compress = @fieldParentPtr(
        CompressStep,
        "step",
        step,
    );
    _ = prog_node;
    // step.dump(std.io.getStdOut());

    compress.output_file.path = "src/asset_gen.zig";
    const out_path = compress.output_file.getPath();
    std.log.warn("out: {s}", .{out_path});

    const cwd = std.fs.cwd();
    compress.fd = try cwd.createFile(out_path, .{});
    defer compress.fd.close();

    try compress.fd.writeAll(prefix);

    try RecursiveDirIterator.run(
        processEntry,
        compress.dir.path,
        cwd,
        compress,
    );

    try compress.fd.writeAll(suffix);

    var all_cached = true;

    for (step.dependencies.items) |dep| {
        all_cached = all_cached and dep.result_cached;
    }

    step.result_cached = all_cached;
}

fn processEntry(d: std.fs.Dir, base: []const u8, p: []const u8, e: []const u8, compress: *CompressStep) !void {
    const out_writer = compress.fd.writer();
    const allocator = compress.step.owner.allocator;
    const realpath = try d.realpathAlloc(
        allocator,
        ".",
    );
    defer allocator.free(realpath);
    var base_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const real_base = try std.fs.realpath(base, &base_buffer);

    const fullpath = try std.fs.path.join(
        allocator,
        &[_][]const u8{ realpath, p, e },
    );
    defer allocator.free(fullpath);
    const relpath = fullpath[real_base.len + 1 ..];

    const fd = try std.fs.openFileAbsolute(
        fullpath,
        .{},
    );
    defer fd.close();

    const content = try fd.readToEndAlloc(allocator, 1073741824);
    defer allocator.free(content);

    try compress.fd.writeAll(".{ ");
    try out_writer.print(
        "\"{}\"",
        .{
            std.zig.fmtEscapes(relpath),
        },
    );
    try compress.fd.writeAll(",.{.body=");
    try out_writer.print(
        "\"{}\"",
        .{
            std.zig.fmtEscapes(content),
        },
    );
    try compress.fd.writeAll(", .compression=.Raw}},\n");

    // _ = std.compress.deflate.compressor(allocator, compress.fd.writer(), .{

    // });

    // try compress.fd.writeAll(content);
}

const RecursiveDirIterator = struct {
    pub fn run(
        entryFn: anytype,
        base: []const u8,
        dir: std.fs.Dir,
        args: anytype,
    ) !void {
        return iter(entryFn, base, dir, base, args);
    }

    fn iter(
        entryFn: anytype,
        base: []const u8,
        dir: std.fs.Dir,
        path: []const u8,
        args: anytype,
    ) !void {
        var fd = try dir.openDir(
            path,
            std.fs.Dir.OpenDirOptions{
                .access_sub_paths = true,
                .no_follow = true,
            },
        );
        defer fd.close();
        var fd_iter = try fd.openIterableDir(
            ".",
            std.fs.Dir.OpenDirOptions{
                .access_sub_paths = true,
                .no_follow = true,
            },
        );
        defer fd_iter.close();

        var dir_iter = fd_iter.iterate();
        while (try dir_iter.next()) |entry| {
            switch (entry.kind) {
                .directory => {
                    std.log.warn("Entering {s},{s},{s}", .{ base, path, entry.name });
                    try RecursiveDirIterator.iter(entryFn, base, fd, entry.name, args);
                },
                else => {
                    try entryFn(dir, base, path, entry.name, args);
                },
            }
        }
    }
};
