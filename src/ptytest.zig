const std = @import("std");

const c = @cImport({
//     #include <stdlib.h>
// #include <sys/types.h>
// #include <sys/socket.h>
// #include <sys/signal.h>
// #include <sys/ioctl.h>
// #include <sys/wait.h>
// #include <sys/poll.h>
// #include <netinet/in.h>
// #include <pty.h>
// #include <arpa/inet.h>
// #include <unistd.h>
    @cInclude("stdlib.h");
    @cInclude("stdio.h");
    @cInclude("errno.h");
    @cInclude("assert.h");
    @cInclude("string.h");
    @cInclude("pty.h");
    @cInclude("utmp.h");
});

pub fn main() !void {
    const stderr = std.io.getStdErr().writer();
    var master: c_int = undefined;
    var slave: c_int = undefined;
    var name = try std.heap.page_allocator.dupeZ(u8, "test");
    const pid = c.openpty(
        master,
        slave,
        name,
        null,
        null,
    );
    // defer c.close(master);
    // defer c.close(slave);

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
