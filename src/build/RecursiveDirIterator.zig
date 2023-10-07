// pass a function pointer to execute on each file found
// recursively in a base directory path

const std = @import("std");
const RecursiveDirIterator = @This();
pub const PathArray = std.ArrayList(u8);

pub fn run(
    allocator: std.mem.Allocator,
    entryFn: anytype,
    base: []const u8,
    args: anytype,
) !void {
    var p = try PathArray.initCapacity(allocator, std.fs.MAX_PATH_BYTES);
    defer p.deinit();
    try p.appendSlice(base);

    return iter(entryFn, base, &p, args);
}

fn iter(
    entryFn: anytype, // Function Pointer to run on all files
    base: []const u8,
    path: *PathArray,
    args: anytype, // last argument to the function
) !void {
    // std.log.debug("Iterating: {s},{s}", .{ base, path.items});
    var fd = try std.fs.cwd().openDir(
        path.items,
        .{
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
        try path.appendSlice(std.fs.path.sep_str);
        try path.appendSlice(entry.name);
        switch (entry.kind) {
            .directory => {
                // std.log.debug("Iterator Entering: {s},{s},{s}", .{ base, path.items, entry.name });
                try RecursiveDirIterator.iter(entryFn, base, path, args);
            },
            .file => {
                // std.log.debug("Processing File: {s},{s},{s}", .{ base, path.items, entry.name });
                try entryFn(base, path.items, entry.name, args);
            },
            else => {
                return error.NOTSUPPORTED;
            },
        }
        try path.resize(path.items.len - entry.name.len - std.fs.path.sep_str.len);
    }
}
