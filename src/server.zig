const std = @import("std");
const zap = @import("zap");
const fio = @import("fio.zig");
const Endpoint = @import("server_endpoint.zig");

fn on_request(r: zap.SimpleRequest) void {
    if (r.path == null) {
        return r.sendBody("<html><body><h1>500 - Header Error</h1></body></html>") catch return;
    }
    const path = r.path.?;
    if (std.mem.eql(u8, path, "/client.wasm")) {
        r.setHeader("content-type", "application/wasm") catch return;
        r.sendBody(@embedFile("client.wasm")) catch return;
        return;
    }
    if (static_map.has(path)) {
        const res = static_map.get(path).?;

        r.setHeader("content-type", res.content_type) catch { 
            r.setStatus(.internal_server_error);
            r.sendBody("<html><body><h1>500 - Header Error</h1></body></html>") catch return;
        };
        r.sendBody(res.body) catch return;
        return;
    }
    r.setStatus(.not_found);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    var allocator = gpa.allocator();
    const wasm_ext = "wasm";
    fio.http_mimetype_register(@constCast(wasm_ext.ptr), wasm_ext.len, 1);

    var listener = zap.SimpleEndpointListener.init(allocator, .{
        .port = 3000,
        .on_request = on_request,
        .max_clients = 100000,
        // .public_folder = "zig-out",
        .log = true,
    });

    // var endpoint = Endpoint.init(allocator, "/client.wasm");
    // defer endpoint.deinit();
    // try listener.addEndpoint(&endpoint.endpoint);

    try listener.listen();

    std.debug.print("\nOpen http://127.0.0.1:3000 in your browser\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 4,
        .workers = 2,
    });
}

const StaticResponse = struct {
    content_type: []const u8 = "text/html",
    body: []const u8,
};

const static_map = std.ComptimeStringMap(StaticResponse, [_]struct { []const u8, StaticResponse }{
    .{ "/", .{ .body = @embedFile("index.html") } },
    .{ "/index.html", .{ .body = @embedFile("index.html") } },
    .{ "/index.js", .{
        .body = @embedFile("index.js"),
        .content_type = "text/javascript",
    } },
    .{ "/xterm.min.js", .{
        .body = @embedFile("xterm.min.js"),
        .content_type = "text/javascript",
    } },
    .{ "/xterm.min.css", .{
        .body = @embedFile("xterm.min.css"),
        .content_type = "text/css",
    } },
});
