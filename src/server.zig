const std = @import("std");
const zap = @import("zap");
const fio = @import("fio.zig");
const Endpoint = @import("server_endpoint.zig");
const assets = @import("assets.zig");

fn on_request(r: zap.SimpleRequest) void {
    if (r.path == null) {
        return server_error(r, "500 - Header Error");
    }
    const path = r.path.?;
    if (std.mem.eql(u8, path, "/client.wasm")) {
        r.setHeader("content-type", "application/wasm") catch 
            server_error(r, "500 - Set Content-Type Error");
        r.sendBody(@embedFile("client.wasm")) catch 
            server_error(r, "500 - Sending Body Error");
        return;
    }
    if (assets.map.has(path)) {
        const res = assets.map.get(path).?;

        r.setHeader("Content-Type", res.content_type) catch
            server_error(r, "500 - Set Content-Type Error");
        r.sendBody(res.body) catch
            server_error(r, "500 - Sending Body Error");
        return;
    }
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
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

pub fn server_error(r: zap.SimpleRequest, msg: []const u8) void {
    r.setStatus(.internal_server_error);
    r.sendBody("<html><body><h1>") catch return;
    r.sendBody(msg) catch return;
    r.sendBody("</h1></body></html>") catch return;
}
