const std = @import("std");

pub const assets_path = "assets";
pub const StaticResponse = struct {
    content_type: []const u8 = "text/html",
    body: []const u8,
};

pub inline fn embedAsset(p: []const u8) []const u8 {
    return @embedFile(assets_path++p);
}

pub const map = std.ComptimeStringMap(StaticResponse, [_]struct { []const u8, StaticResponse }{
    .{ "/", .{ .body = @embedFile(assets_path++"/index.html") } },
    .{ "/index.html", .{ .body = @embedFile(assets_path++"/index.html") } },
    .{ "/index.js", .{
        .body = @embedFile(assets_path++"/index.js"),
        .content_type = "text/javascript",
    } },
    .{ "/client.wasm", .{
        .body = @embedFile(assets_path++"/client.wasm"),
        .content_type = "application/wasm",
    } },
    .{ "/xterm.min.js", .{
        .body = @embedFile(assets_path++"/xterm.min.js"),
        .content_type = "text/javascript",
    } },
    .{ "/xterm.min.css", .{
        .body = @embedFile(assets_path++"/xterm.min.css"),
        .content_type = "text/css",
    } },
    .{ "/xterm-addon-attach.min.js", .{
        .body = @embedFile(assets_path++"/xterm-addon-attach.min.js"),
        .content_type = "text/javascript",
    } },
});