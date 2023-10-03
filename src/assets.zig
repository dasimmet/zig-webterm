const std = @import("std");

pub const assets_path = "assets/";
pub const StaticResponse = struct {
    content_type: []const u8 = "text/html",
    body: []const u8,
};

pub inline fn embedAsset(p: []const u8) []const u8 {
    return @embedFile(assets_path ++ p);
}

// a map of path on the server to the embedded response
pub const map = std.ComptimeStringMap(StaticResponse, [_]struct {
    []const u8,
    StaticResponse,
}{
    .{ "/", .{ .body = embedAsset("index.html") } },
    .{ "/index.html", .{ .body = embedAsset("index.html") } },
    .{ "/index.js", .{
        .body = embedAsset("index.js"),
        .content_type = "text/javascript",
    } },
    .{ "/client.wasm", .{
        .body = embedAsset("client.wasm"),
        .content_type = "application/wasm",
    } },
    .{ "/xterm.min.js", .{
        .body = embedAsset("xterm.min.js"),
        .content_type = "text/javascript",
    } },
    .{ "/xterm.min.css", .{
        .body = embedAsset("xterm.min.css"),
        .content_type = "text/css",
    } },
    .{ "/xterm-addon-attach.min.js", .{
        .body = embedAsset("xterm-addon-attach.min.js"),
        .content_type = "text/javascript",
    } },
    .{ "/xterm-addon-fit.min.js", .{
        .body = embedAsset("xterm-addon-fit.min.js"),
        .content_type = "text/javascript",
    } },
});

pub const CompressStep = struct {
    step: std.build.Step,
    dir: std.build.LazyPath,
    output_file: std.Build.GeneratedFile,
    fd: std.fs.File = undefined,

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
};

const prefix =
    \\// a map of path on the server to the embedded response
    \\const std = @import("std");
    \\pub const map = std.ComptimeStringMap([]const u8, [_]struct {
    \\    []const u8,
    \\    []const u8,
    \\}{
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

    const cwd = std.fs.cwd();
    compress.fd = try cwd.createFile("out.zig", .{});
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

fn processEntry(d: std.fs.Dir, base: []const u8,p: []const u8, e: []const u8, compress: *CompressStep) !void {
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
    const relpath = fullpath[real_base.len+1..];

    const fd = try std.fs.openFileAbsolute(
        fullpath,
        .{},
    );
    defer fd.close();

    const content = try fd.readToEndAlloc(allocator, 1073741824);
    defer allocator.free(content);

    try compress.fd.writeAll(".{ \"");
    const key_formatter = std.zig.fmtEscapes(relpath);
    try key_formatter.format("", .{}, compress.fd.writer());
    try compress.fd.writeAll("\",\"");

    const content_formatter = std.zig.fmtEscapes(content);
    try content_formatter.format("", .{}, compress.fd.writer());
    try compress.fd.writeAll("\"},\n");
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
