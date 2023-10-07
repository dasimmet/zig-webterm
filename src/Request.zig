const std = @import("std");
const zap = @import("zap");
const assets = @import("assets");
const Response = @import("Response.zig");

pub fn on_request(r: zap.SimpleRequest) void {
    if (r.path == null) {
        return Response.server_error(r, "500 - Header Error");
    }
    var path = std.mem.trimLeft(u8, r.path.?, "/");
    if (std.mem.eql(u8, path, "")) {
        path = "index.html";
    }
    if (assets.map().get(path)) |res| {
        Response.render(r, path, res);
        return;
    }
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
}
