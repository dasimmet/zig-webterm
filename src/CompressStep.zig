const std = @import("std");
const builtin = @import("builtin");
const RecursiveDirIterator = @import("RecursiveDirIterator.zig");

step: std.build.Step,
dir: std.build.LazyPath,
source_path: ?std.build.LazyPath = null,
output_file: std.Build.GeneratedFile,
fd: std.fs.File = undefined,
method: Method = .Raw,
max_file_size: usize = 1073741824,

const CompressStep = @This();

const Header =
    \\pub const zig_version_string = "{}";
    \\pub const map = std.ComptimeStringMap(
    \\    Entry(.{s}),
    \\    [_]EntryMap(.{s}){{
    \\
;
const Footer = "});\n";

pub const Method = @import("CompressHeader.zig").Method;

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

fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    const b = step.owner;
    const allocator = b.allocator;

    var compress = @fieldParentPtr(
        CompressStep,
        "step",
        step,
    );

    var man = b.cache.obtain();
    defer man.deinit();
    const cwd = std.fs.cwd();

    // the coolest hack when working on caching mechanisms is to include the source :-D
    // but dont forget to quote this before committing
    // _ = try man.addFile(@src().file, compress.max_file_size);

    man.hash.addBytes(@embedFile("CompressHeader.zig"));
    man.hash.addBytes(@typeName(CompressStep));
    man.hash.addBytes(Header);
    man.hash.addBytes(@typeName(Method));
    man.hash.addBytes(@tagName(compress.method));

    if (compress.source_path != null) man.hash.addBytes(compress.source_path.?.path);
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
    if (try man.hit()) {
        const digest = man.final();
        compress.output_file.path = try b.cache_root.join(allocator, &.{
            "o", &digest, "compress.zig",
        });
        // std.log.warn("HIT: {s}", .{compress.output_file.path.?});
        step.result_cached = true;
        return;
    }
    step.result_cached = false;
    const digest = man.final();

    if (compress.source_path) |p| {
        compress.output_file.path = p.path;
    } else {
        compress.output_file.path = try b.cache_root.join(allocator, &.{
            "o", &digest, "compress.zig",
        });
    }
    // std.log.debug("DIGEST: {s}", .{digest});

    const out_path = compress.output_file.getPath();
    // std.log.debug("out: {s}", .{out_path});

    const out_dir = std.fs.path.dirname(out_path).?;
    try cwd.makeDir(out_dir);

    compress.fd = try cwd.createFile(out_path, .{});
    defer compress.fd.close();

    _ = try compress.fd.write(@embedFile("CompressHeader.zig"));
    try compress.fd.writer().print(Header, .{
        std.zig.fmtEscapes(builtin.zig_version_string),
        @tagName(compress.method),
        @tagName(compress.method),
    });

    try RecursiveDirIterator.run(
        processEntry,
        compress.dir.path,
        cwd,
        compress,
    );

    try compress.fd.writeAll(Footer);
    try step.writeManifest(&man);
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
    _ = try ctx.man.addFile(fullpath, compress.max_file_size);
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

    try out_writer.print(
        ".{{\"{}\",\n.{{\n",
        .{
            std.zig.fmtEscapes(relpath),
        },
    );
    try out_writer.print(
        ".source=\"{}\",\n.body=",
        .{
            std.zig.fmtEscapes(fullpath),
        },
    );
    switch (compress.method) {
        .Deflate => {
            const content = try fd.readToEndAlloc(allocator, compress.max_file_size);
            var compressed = std.ArrayList(u8).init(allocator);
            defer compressed.deinit();

            var Compressor = try std.compress.deflate.compressor(
                allocator,
                compressed.writer(),
                .{},
            );
            defer Compressor.deinit();

            _ = try Compressor.write(content);
            try Compressor.flush();
            try out_writer.print(
                "\"{}\"",
                .{
                    std.zig.fmtEscapes(compressed.items),
                },
            );
        },
        .Raw => {
            const content = try fd.readToEndAlloc(allocator, compress.max_file_size);
            try out_writer.print(
                "\"{}\"",
                .{
                    std.zig.fmtEscapes(content),
                },
            );
        },
        .Gzip => {
            return error.TODO;
        },
        .XZ => {
            const content = try compress_file_to_mem(fd, compress.method);
            try out_writer.print(
                "\"{}\"",
                .{
                    std.zig.fmtEscapes(content),
                },
            );
        },
    }
    try compress.fd.writeAll(",\n}},\n");
}

pub fn compress_file_to_mem(file: std.fs.File, comp: Method) ![]const u8 {
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
