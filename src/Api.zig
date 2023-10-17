const zap = @import("zap");
const Websocket = @import("Websocket.zig");

pub fn init(listener: zap.SimpleEndpointListener) void {
    Websocket.GlobalContextManager =
        Websocket.ContextManager.init(
        &[_][]const u8{ "ls", "-alsh" },
        listener.allocator,
        "wololo",
        "derp-",
    );
}

pub fn on_upgrade(ctx: *void, r: zap.SimpleRequest, proto: []const u8) void {
    _ = ctx;
    Websocket.on_upgrade(r, proto);
}

pub fn on_request(ctx: *void, r: zap.SimpleRequest) void {
    _ = ctx;
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
}
