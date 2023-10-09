const std = @import("std");
const zap = @import("zap");
const assets = @import("assets");

const Response = @This();

pub fn render(r: zap.SimpleRequest, path: []const u8, res: assets.EntryType) void {
    _ = path;
    r.setStatus(.ok);
    if (res.method == .Deflate) {
        r.setHeader("Content-Encoding", "deflate") catch
            server_error(r, "500 - Set Content-Encoding Error");
    }
    if (res.method == .Gzip) {
        r.setHeader("Content-Encoding", "gzip") catch
            server_error(r, "500 - Set Content-Encoding Error");
    }
    if (res.method == .ZStd) {
        r.setHeader("Content-Encoding", "zstd") catch
            server_error(r, "500 - Set Content-Encoding Error");
    }
    r.setHeader("Content-Type", res.mimetype) catch
        return server_error(r, "500 - Set Content-Type Error");

    var buf: [64]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "{d}", .{res.body.len}) catch
        return server_error(r, "500 - Buffer Overflow");
    r.setHeader("content-length", len) catch
        return server_error(r, "500 - Set Content-Length Error");
    r.sendBody(res.body) catch
        return server_error(r, "500 - Sending Body Error");
}

pub fn server_error(r: zap.SimpleRequest, msg: []const u8) void {
    r.setStatus(.internal_server_error);
    r.sendBody("<html><body><h1>") catch return;
    r.sendBody(msg) catch return;
    r.sendBody("</h1></body></html>") catch return;
}
