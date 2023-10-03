const std = @import("std");
const zap = @import("zap");
const assets = @import("assets.zig");

pub fn on_request(r: zap.SimpleRequest) void {
    if (r.path == null) {
        return server_error(r, "500 - Header Error");
    }
    const path = r.path.?;
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

pub fn server_error(r: zap.SimpleRequest, msg: []const u8) void {
    r.setStatus(.internal_server_error);
    r.sendBody("<html><body><h1>") catch return;
    r.sendBody(msg) catch return;
    r.sendBody("</h1></body></html>") catch return;
}
