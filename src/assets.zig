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
    .{ "/", .{ .body = embedAsset("/index.html") } },
    .{ "/index.html", .{ .body = embedAsset("/index.html") } },
    .{ "/index.js", .{
        .body = embedAsset("/index.js"),
        .content_type = "text/javascript",
    } },
    .{ "/client.wasm", .{
        .body = embedAsset("/client.wasm"),
        .content_type = "application/wasm",
    } },
    .{ "/xterm.min.js", .{
        .body = embedAsset("/xterm.min.js"),
        .content_type = "text/javascript",
    } },
    .{ "/xterm.min.css", .{
        .body = embedAsset("/xterm.min.css"),
        .content_type = "text/css",
    } },
    .{ "/xterm-addon-attach.min.js", .{
        .body = embedAsset("/xterm-addon-attach.min.js"),
        .content_type = "text/javascript",
    } },
});