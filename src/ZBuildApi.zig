const zap = @import("zap");

pub const on_upgrade = @import("Websocket.zig").on_upgrade;

pub fn on_request(r: zap.SimpleRequest) void {
    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404 - Not Found</h1></body></html>") catch return;
}