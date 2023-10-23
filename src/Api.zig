const zap = @import("zap");
const Websocket = @import("Websocket.zig");

pub const Context = struct {
    WsMan: Websocket.ContextManager,
};

pub fn init(listener: zap.SimpleEndpointListener) Context {
    return .{
        .WsMan = Websocket.ContextManager.init(
            &[_][]const u8{ "ls", "-alsh" },
            listener.allocator,
            "wololo",
            "derp-",
        ),
    };
}

pub fn on_upgrade(ctx: *Context, r: zap.SimpleRequest, proto: []const u8) void {
    Websocket.on_upgrade(&ctx.WsMan, r, proto);
}

pub fn on_request(ctx: *Context, r: zap.SimpleRequest) void {
    _ = ctx;
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
}
