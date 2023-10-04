const std = @import("std");

step: std.build.Step,
dir: std.build.LazyPath,
output_file: std.Build.GeneratedFile,
fd: std.fs.File = undefined,
compression: Compression = .XZ,

const CompressStep = @This();
pub const Compression = enum {
    Raw,
    Gzip,
    Deflate,
    XZ,
};

const CacheContext = struct {
    compress: *CompressStep,
    man: *std.Build.Cache.Manifest,
};

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
    \\  Deflate,
    \\  XZ,
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
    _ = prog_node;
    var compress = @fieldParentPtr(
        CompressStep,
        "step",
        step,
    );

    const b = step.owner;
    var man = b.cache.obtain();
    defer man.deinit();
    const cwd = std.fs.cwd();
    
    man.hash.addBytes(compress.dir.path);

    var cacheContext: CacheContext = .{
        .compress = compress,
        .man = &man,
    };
    try RecursiveDirIterator.run(
        cacheEntry,
        compress.dir.path,
        cwd,
        &cacheContext,
    );
    
    // if (try step.cacheHit(&man)) {
    // const digest = man.final();
    // std.log.warn("Digest: {s}", .{digest});

    // step.dump(std.io.getStdOut());
    var all_cached = false;

    for (step.dependencies.items) |dep| {
        all_cached = all_cached and dep.result_cached;
    }

    step.result_cached = all_cached;
    if (all_cached) return;

    compress.output_file.path = "src/asset_gen.zig";
    const out_path = compress.output_file.getPath();
    std.log.warn("out: {s}", .{out_path});

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
}

fn cacheEntry(d: std.fs.Dir, base: []const u8, p: []const u8, e: []const u8, ctx: *CacheContext) !void {
    const compress: *CompressStep = ctx.compress;
    const allocator = compress.step.owner.allocator;
    const realpath = try d.realpathAlloc(
        allocator,
        ".",
    );
    defer allocator.free(realpath);
    var base_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const real_base = try std.fs.realpath(base, &base_buffer);
    _ = real_base;

    const fullpath = try std.fs.path.join(
        allocator,
        &[_][]const u8{ realpath, p, e },
    );
    defer allocator.free(fullpath);
    ctx.man.hash.addBytes(fullpath);
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

    try compress.fd.writeAll(".{ ");
    try out_writer.print(
        "\"{}\"",
        .{
            std.zig.fmtEscapes(relpath),
        },
    );

    var content: ?[]const u8 = null;
    if (compress.compression != .XZ){
        content = try fd.readToEndAlloc(allocator, 1073741824);
        defer allocator.free(content.?);
    } 

    switch (compress.compression) {
        .Deflate => {
            try compress.fd.writeAll(",.{.compression=.Deflate, .body=");
            var compressed = std.ArrayList(u8).init(allocator);
            defer compressed.deinit();

            var Compressor = try std.compress.deflate.compressor(
                allocator,
                compressed.writer(),
                .{},
            );
            defer Compressor.deinit();

            _ = try Compressor.write(content.?);
            try Compressor.flush();
        },
        .Raw => {
        },
        .Gzip => {
            return error.TODO;
        },
        .XZ => {
            try compress.fd.writeAll(",.{.compression=.XZ, .body=");
            content = try compress_file_to_mem(fd, compress.compression);
        }
    }
    if (content) |c| {
        try out_writer.print(
            "\"{}\"",
            .{
                std.zig.fmtEscapes(c),
            },
        );
    }
    try compress.fd.writeAll("}},\n");
}

pub fn compress_file_to_mem(file: std.fs.File, comp: Compression) ![]const u8 {
    _ = file;
    var body: []const u8 = undefined;
    switch (comp) {
        .XZ => {
            body = "TODO";
        },
        else => return error.TODO,
    }
    return body;
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
