const std = @import("std");

const Process = @This();

proc: std.ChildProcess,
thread: std.Thread,

pub fn run(self: *Process, allocator: std.mem.Allocator, comptime contextType: type) !void {
    const ctx = @fieldParentPtr(contextType, "process", self);

    try self.proc.spawn();
    var poller = std.io.poll(allocator, enum { stdout, stderr }, .{
        .stdout = self.proc.stdout.?,
        .stderr = self.proc.stderr.?,
    });
    defer poller.deinit();

    var buf: [4096]u8 = undefined;
    while (try poller.poll()) {
        if (poller.fifo(.stdout).count > 0) {
            const fifo = poller.fifo(.stdout);
            const msg_len = try fifo.reader().read(&buf);
            const message = buf[0..msg_len];

            ctx.publish(message);
            // std.log.info("stdout:{s}", .{message});
        }
        if (poller.fifo(.stderr).count > 0) {
            const fifo = poller.fifo(.stderr);
            const msg_len = try fifo.reader().read(&buf);
            const message = buf[0..msg_len];

            ctx.publish(message);
            // std.log.info("stderr:{s}", .{message});
        }

        if (!ctx.connected) {
            const term = try self.proc.kill();
            std.debug.print("Process exited with status {}\n", .{term});
        }
    }
}
