const std = @import("std");
const Server = std.http.Server;
const Handler = @import("handler.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const max_header_size = 8192;
const ip = "0.0.0.0";

pub fn main() !void {
    var srv = Server.init(allocator, .{ .reuse_address = true });
    defer srv.deinit();
    
    try srv.listen(try std.net.Address.parseIp(ip, 0));

    const port = srv.socket.listen_address.getPort();
    var url = try std.fmt.allocPrint(allocator, "http://{s}:{}", .{ip,port});
    defer allocator.free(url);
    std.debug.print("Listening on: {s}\n", .{url});

    var handle_new_requests = true;

    // _ = try std.ChildProcess.exec(.{
    //     .allocator=allocator,
    //     .argv=&[_][]const u8{"xdg-open",url},
    // });

    var handle = Handler{.allocator=allocator};

    outer: while (handle_new_requests) {
         var res = try srv.accept(.{
            .allocator = allocator,
            .header_strategy = .{ .dynamic = max_header_size },
        });
        defer res.deinit();

        while (res.reset() != .closing) {
            res.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            try handle.handleRequest(&res);
        }
    }
}
