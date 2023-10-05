const std = @import("std");
const builtin = @import("builtin");
pub const RecursiveDirIterator = @import("RecursiveDirIterator.zig");
pub const CompressHeader = @import("CompressHeader.zig");
pub const Method = CompressHeader.Method;

step: std.build.Step,
dir: std.build.LazyPath,
method: Method = .Raw,
max_file_size: usize = 1073741824,
embed_full_path: bool = false,

fd: std.fs.File = undefined,
output_file: std.Build.GeneratedFile,

const CompressStep = @This();

const Header =
    \\pub const zig_version_string = "{}";
    \\pub const EntryType = Entry(.{s});
    \\pub const map = std.ComptimeStringMap(
    \\    EntryType,
    \\    [_]EntryMap(.{s}){{
    \\
;
const Footer = "});\n";

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

fn hash(compress: *CompressStep, man: *std.Build.Cache.Manifest) void {
    man.hash.addBytes(compress.step.name);
    man.hash.addBytes(@embedFile("CompressHeader.zig"));
    man.hash.addBytes(compress.dir.path);
    man.hash.add(compress.method);
    man.hash.add(compress.embed_full_path);
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

    compress.hash(&man);

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
        // std.log.warn("HIT: {s}", .{compress.output_file.path.?});
        step.result_cached = true;
    } else {
        step.result_cached = false;
    }
    const digest = man.final();

    compress.output_file.path = try b.cache_root.join(allocator, &.{
        "o", &digest, "compress.zig",
    });

    if (step.result_cached) return;
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

const CacheContext = struct {
    compress: *CompressStep,
    man: *std.Build.Cache.Manifest,
};

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
    if (compress.embed_full_path) try out_writer.print(
        ".full_path=\"{}\",\n",
        .{
            std.zig.fmtEscapes(fullpath),
        },
    );
    try out_writer.writeAll(".body=");
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
            defer allocator.free(content);

            try out_writer.print(
                "\"{}\"",
                .{
                    std.zig.fmtEscapes(content),
                },
            );
        },
        .Gzip => {
            const content = try compress.file_to_mem(fullpath, compress.method);
            defer allocator.free(content);

            try out_writer.print(
                "\"{}\"",
                .{
                    std.zig.fmtEscapes(content),
                },
            );
        },
        .XZ, .ZStd => {
            const content = try compress.file_to_mem(fullpath, compress.method);
            defer allocator.free(content);
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

pub fn file_to_mem(compress: CompressStep, path: []const u8, comp: Method) ![]const u8 {
    const allocator = compress.step.owner.allocator;

    var body: []const u8 = undefined;
    switch (comp) {
        .XZ => {
            var proc = try std.ChildProcess.exec(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "xz", "-T0", "-c", "--", path },
                .max_output_bytes = compress.max_file_size,
            });
            defer allocator.free(proc.stderr);

            body = proc.stdout;
        },
        .Gzip => {
            var proc = try std.ChildProcess.exec(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "gzip", "-9", "-c", "--", path },
                .max_output_bytes = compress.max_file_size,
            });
            defer allocator.free(proc.stderr);

            body = proc.stdout;
        },
        .ZStd => {
            var proc = try std.ChildProcess.exec(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "zstd", "-9", "-c", "--", path },
                .max_output_bytes = compress.max_file_size,
            });
            defer allocator.free(proc.stderr);

            body = proc.stdout;
        },
        else => return error.TODO,
    }
    return body;
}
