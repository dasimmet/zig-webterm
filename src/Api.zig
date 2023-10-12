const zap = @import("zap");
const Websocket = @import("Websocket.zig");

pub fn on_init(listener: zap.SimpleEndpointListener) void {
    Websocket.GlobalContextManager =
        Websocket.ContextManager.init(
            &[_][]const u8{ "ls", "-alsh" },
            listener.allocator,
            "wololo",
            "derp-",
        );
}

pub const on_upgrade = Websocket.on_upgrade;

pub fn on_request(r: zap.SimpleRequest) void {
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
}
