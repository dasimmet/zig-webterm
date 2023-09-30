const std = @import("std");

pub const StaticResponse = struct {
    content_type: []const u8 = "text/html",
    body: []const u8,
};

pub const map = std.ComptimeStringMap(StaticResponse, [_]struct { []const u8, StaticResponse }{
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
    .{ "/xterm-addon-attach.min.js", .{
        .body = @embedFile("xterm-addon-attach.min.js"),
        .content_type = "text/javascript",
    } },
});
