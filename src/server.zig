const std = @import("std");
const zap = @import("zap");

const Request = @import("Request.zig");
const Websocket = @import("Websocket.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    var allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer allocator.free(argv);

    for (argv) |a| {
        std.log.warn("argv: {s}", .{a});
    }

    Websocket.GlobalContextManager = Websocket.ContextManager.init(
        argv[1..],
        allocator,
        "WUFF",
        "derp_",
    );

    var listener = zap.SimpleEndpointListener.init(allocator, .{
        .port = 3000,
        .on_upgrade = Websocket.on_upgrade,
        .on_request = Request.on_request,
        .max_clients = 100000,
        // .public_folder = "zig-out",
        .log = true,
    });

    try listener.listen();

    std.debug.print("\nOpen http://127.0.0.1:3000 in your browser\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 4,
        .workers = 2,
    });
}
