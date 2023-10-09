// a generated map of embedded files using string literals.
// Usage: @import("assets").map()

const std = @import("std");

// this will be multiplied by the number of entries
// and passed to @setEvalBranchQuota to
// allow importing programs to compile the map
// this depends on  the implementation of ComptimeStringMap
// and was optimized by trial and error
// for zig version "0.12.0-dev.790+ad6f8e3a5"
const EvalBranchQuotaMultiplier = 30;

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
pub fn EntryMap(comptime method: type) type {
    return struct {
        []const u8,
        method,
    };
}
