const std = @import("std");
const RecursiveDirIterator = @This();

pub fn run(
    entryFn: anytype,
    base: []const u8,
    dir: std.fs.Dir,
    args: anytype,
) !void {
    return iter(entryFn, base, dir, base, args);
}

fn iter(
    entryFn: anytype, // Function Pointer to run on all files
    base: []const u8,
    dir: std.fs.Dir,
    path: []const u8,
    args: anytype, // last argument to the function
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
                // std.log.debug("Iterator Entering: {s},{s},{s}", .{ base, path, entry.name });
                try RecursiveDirIterator.iter(entryFn, base, fd, entry.name, args);
            },
            .file => {
                try entryFn(dir, base, path, entry.name, args);
            },
            else => {
                return error.NOTSUPPORTED;
            },
        }
    }
}
