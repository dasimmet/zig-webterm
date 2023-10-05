// a map of embedded files
const std = @import("std");
pub const Method = enum {
    Raw,
    Gzip,
    Deflate,
    XZ,
    ZStd,
};
pub fn Entry(comptime method: Method) type {
    return struct {
        full_path: ?[]const u8 = null,
        body: []const u8,
        method: Method = method,
    };
}
pub fn EntryMap(comptime method: Method) type {
    return struct {
        []const u8,
        Entry(method),
    };
}
