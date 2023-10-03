const std = @import("std");

pub const assets_path = "assets/";
pub const StaticResponse = struct {
    content_type: []const u8 = "text/html",
    body: []const u8,
};
const ResponseMap = struct {
    []const u8,
    StaticResponse,
};

pub inline fn embedAsset(p: []const u8) []const u8 {
    return @embedFile(assets_path ++ p);
}

// test importing the generated assets
// const generated_assets = @import("asset_gen.zig");

// pub fn map_lists(kvs: anytype) ResponseMap {
//     _ = kvs;

//     for (generated_assets.map.kvs) |kv| {
//         std.log.warn("KV: {s}", .{kv[0]});
//     }
// }

// pub const map_a = std.ComptimeStringMap(
//     StaticResponse,
//     [_]ResponseMap{},
// );

// a map of path on the server to the embedded response
pub const map = std.ComptimeStringMap(
    StaticResponse,
    [_]ResponseMap{
        .{ "/", .{ .body = embedAsset("index.html") } },
        .{ "/index.html", .{ .body = embedAsset("index.html") } },
        .{ "/index.js", .{
            .body = embedAsset("index.js"),
            .content_type = "text/javascript",
        } },
        .{ "/client.wasm", .{
            .body = embedAsset("client.wasm"),
            .content_type = "application/wasm",
        } },
        .{ "/xterm.min.js", .{
            .body = embedAsset("xterm.min.js"),
            .content_type = "text/javascript",
        } },
        .{ "/xterm.min.css", .{
            .body = embedAsset("xterm.min.css"),
            .content_type = "text/css",
        } },
        .{ "/xterm-addon-attach.min.js", .{
            .body = embedAsset("xterm-addon-attach.min.js"),
            .content_type = "text/javascript",
        } },
        .{ "/xterm-addon-fit.min.js", .{
            .body = embedAsset("xterm-addon-fit.min.js"),
            .content_type = "text/javascript",
        } },
    },
);
