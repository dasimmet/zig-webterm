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
    } else {
        r.setHeader("content-type", "text/html") catch {
            r.setStatus(.internal_server_error);
            r.sendBody("<html><body><h1>500 - Header Error</h1></body></html>") catch return;
        };
    }
    if (std.mem.eql(u8, path, "/index.html")) {
        r.setStatus(.found);
        return static_site(r);
    }
    if (std.mem.eql(u8, r.path.?, "/")) {
        r.setStatus(.found);
        return static_site(r);
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

fn static_site(r: zap.SimpleRequest) void {
    r.sendBody(@embedFile("index.html")) catch return;
}
