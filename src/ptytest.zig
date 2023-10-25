const std = @import("std");

const c = @cImport({
    @cInclude("assert.h");
    @cInclude("stdio.h");
    @cInclude("string.h");
    @cInclude("stdlib.h");
    @cInclude("pty.h");
    @cInclude("utmp.h");
});

pub fn main() !void {
    const stderr = std.io.getStdErr().writer();
    var master: c_int = 10;
    // var name = try std.heap.page_allocator.dupeZ(u8, "test");
    const pid = c.forkpty(
        master,
        0,
        0,
        0,
    );

    if (-1 == pid)
        // forkpty failed
        @panic("could not fork or more pseudo terminals available");

    // are we parent ?
    if (0 != pid) {
        // yes - return with child pid
        try std.fmt.format(stderr, "MASTER! pid: {d}\n", .{pid});
        return;
    }

    try std.fmt.format(stderr, "FORK! pid: {d}\n", .{pid});
}
