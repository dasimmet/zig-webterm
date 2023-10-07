const std = @import("std");
const builtin = @import("builtin");
pub const RecursiveDirIterator = @import("RecursiveDirIterator.zig");
pub const CompressHeader = @import("CompressHeader.zig");
pub const Method = CompressHeader.Method;
// This Step generates a "compress.zig" source code file
// in "out_file" containing a CompressHeader.zig
// as well as a ComptimeStringMap "map" with all
// files in the directory tree below "dir".

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
    \\pub const EntryMapType = EntryMap(EntryType);
    \\
    \\pub const map_size = {d};
    \\const EvalBranchQuota = map_size * EvalBranchQuotaMultiplier;
    \\pub inline fn map() map_t {{
    \\  return std.ComptimeStringMap(EntryType,map_internal);
    \\}}
    \\const map_t = blk: {{
    \\  @setEvalBranchQuota(EvalBranchQuota);
    \\  break :blk @TypeOf(std.ComptimeStringMap(
    \\    EntryType,map_internal));
    \\}};
    \\const map_internal = [_]EntryMapType{{
    \\
;
const Footer = "};\n";

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
        .dir = dir.dupe(b),
        .output_file = .{ .step = &self.step },
    };

    self.dir.addStepDependencies(&self.step);
    return self;
}

fn hash(compress: *CompressStep, man: *std.Build.Cache.Manifest) void {
    man.hash.addBytes(compress.step.name);
    // the coolest hack when working on caching mechanisms is to include the source :-D
    // but dont forget to quote this before committing
    _ = man.addFile(
        @src().file,
        compress.max_file_size,
    ) catch @panic("cannot include source file");
    const compress_dir = compress.dir.getPath2(compress.step.owner, &compress.step);
    man.hash.addBytes(compress_dir);
    man.hash.add(compress.method);
    man.hash.add(compress.embed_full_path);
    man.hash.addBytes(@embedFile("CompressHeader.zig"));
    man.hash.addBytes(Header);
}

fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
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

    compress.hash(&man);

    var ctx: Context = .{
        .compress = compress,
        .man = &man,
        .prog_node = prog_node,
    };
    try RecursiveDirIterator.run(
        allocator,
        cacheEntry,
        compress.dir.getPath2(b, step),
        &ctx,
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
        ctx.prog_node.unprotected_estimated_total_items,
    });

    try RecursiveDirIterator.run(
        allocator,
        processEntry,
        compress.dir.getPath2(b, &compress.step),
        &ctx,
    );

    try compress.fd.writeAll(Footer);
    try step.writeManifest(&man);
}

const Context = struct {
    compress: *CompressStep,
    prog_node: *std.Progress.Node,
    man: *std.Build.Cache.Manifest,
};

fn cacheEntry(base: []const u8, entry_path: []const u8, entry_name: []const u8, ctx: *Context) !void {
    _ = base;
    _ = entry_name;
    ctx.prog_node.setEstimatedTotalItems(ctx.prog_node.unprotected_estimated_total_items + 1);
    const compress: *CompressStep = ctx.compress;

    ctx.man.hash.addBytes(entry_path);
    _ = try ctx.man.addFile(entry_path, compress.max_file_size);
}

fn processEntry(base: []const u8, entry_path: []const u8, entry_name: []const u8, ctx: *Context) !void {
    _ = entry_name;
    const compress = ctx.compress;
    const out_writer = compress.fd.writer();
    const allocator = compress.step.owner.allocator;

    const relpath = entry_path[base.len + 1 ..];

    const fd = try std.fs.openFileAbsolute(
        entry_path,
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
            std.zig.fmtEscapes(entry_path),
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
        .Gzip, .XZ, .ZStd => {
            const content = try compress.file_to_mem(entry_path, compress.method);
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
    ctx.prog_node.completeOne();
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
