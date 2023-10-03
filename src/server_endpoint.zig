const std = @import("std");
const zap = @import("zap");
const builtin = @import("builtin");

// an Endpoint

pub const Self = @This();

alloc: std.mem.Allocator = undefined,
endpoint: zap.SimpleEndpoint = undefined,
server_dir: zap.SimpleEndpoint = undefined,

pub fn init(
    a: std.mem.Allocator,
    route_path: []const u8,
) Self {
    return .{
        .alloc = a,
        .endpoint = zap.SimpleEndpoint.init(.{
            .path = route_path,
            .get = getWasm,
        }),
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn getWasm(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    _ = r;
    _ = e;
    // builtin.
    // std.log.info("EP: {s}", .{r.path.?});
    // r.setHeader("content-type", "application/wasm") catch return;
    // r.sendBody(body) catch return;
}
