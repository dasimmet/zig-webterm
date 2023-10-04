const std = @import("std");
const zap = @import("zap");
const assets = @import("assets");

pub fn on_request(r: zap.SimpleRequest) void {
    if (r.path == null) {
        return server_error(r, "500 - Header Error");
    }
    const path = std.mem.trimLeft(u8, r.path.?, "/");
    if (std.mem.eql(u8, path, "")) {
        const res = assets.map.get("index.html").?;
        process_response(r, path, res);
        return;
    }
    if (assets.map.get(path)) |res| {
        process_response(r, path, res);
        return;
    }
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
}

pub fn process_response(r: zap.SimpleRequest, path: []const u8, res: anytype) void {
    r.setStatus(.ok);
    if (res.compression == .Deflate) {
        std.log.debug("Content-Encoding: Deflate", .{});
        r.setHeader("Content-Encoding", "deflate") catch
            server_error(r, "500 - Set Content-Encoding Error");
    }
    const extension = std.fs.path.extension(path);
    const mime = mime_map.get(extension) orelse "text/html";

    r.setHeader("Content-Type", mime) catch
        server_error(r, "500 - Set Content-Type Error");
    r.setHeader("Content-Type", "text/html") catch
        server_error(r, "500 - Set Content-Type Error");
    r.sendBody(res.body) catch
        server_error(r, "500 - Sending Body Error");
}

pub fn server_error(r: zap.SimpleRequest, msg: []const u8) void {
    r.setStatus(.internal_server_error);
    r.sendBody("<html><body><h1>") catch return;
    r.sendBody(msg) catch return;
    r.sendBody("</h1></body></html>") catch return;
}

pub const mime_map = std.ComptimeStringMap([]const u8, [_]struct {
    []const u8,
    []const u8,
}{
    .{ "wasm", "application/wasm" },
    .{ "js", "text/javascript" },
    .{ "css", "text/css" },
    .{ "html", "text/html" },
});
