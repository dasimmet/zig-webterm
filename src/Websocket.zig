const std = @import("std");
const zap = @import("zap");
const WebSockets = zap.WebSockets;

const Process = @import("Process.zig");

// global variables, yeah!
pub var GlobalContextManager: ContextManager = undefined;
pub const WebsocketHandler = WebSockets.Handler(Context);

const Context = struct {
    manager: *ContextManager,
    connected: bool = true,
    userName: []const u8,
    channel: []const u8,
    process: Process,
    // we need to hold on to them and just re-use them for every incoming
    // connection
    subscribeArgs: WebsocketHandler.SubscribeArgs,
    settings: WebsocketHandler.WebSocketSettings,

    pub fn deinit(ctx: *Context) void {
        ctx.connected = false;
        ctx.process.proc.stdin.?.close();
        ctx.process.proc.stdout.?.close();
        ctx.process.proc.stderr.?.close();
        ctx.process.thread.join();
    }

    pub fn publish(ctx: Context, message: []const u8) void {
        const opts = .{ .channel = ctx.channel, .message = message };
        return WebsocketHandler.publish(opts);
    }
};

pub fn runProcess(self: *Context, allocator: std.mem.Allocator) !void {
    try self.process.run(allocator, Context);
}

const ContextList = std.ArrayList(*Context);

pub const ContextManager = struct {
    argv: []const []const u8,
    allocator: std.mem.Allocator,
    channel: []const u8,
    usernamePrefix: []const u8,
    lock: std.Thread.Mutex = .{},
    contexts: ContextList = undefined,

    const Self = @This();

    pub fn init(
        argv: []const []const u8,
        allocator: std.mem.Allocator,
        channelName: []const u8,
        usernamePrefix: []const u8,
    ) Self {
        return .{
            .argv = argv,
            .allocator = allocator,
            .channel = channelName,
            .usernamePrefix = usernamePrefix,
            .contexts = ContextList.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.contexts.items) |ctx| {
            self.allocator.free(ctx.userName);
        }
        self.contexts.deinit();
    }

    pub fn newContext(self: *Self) !*Context {
        self.lock.lock();
        defer self.lock.unlock();

        var ctx = try self.allocator.create(Context);
        var userName = try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ self.usernamePrefix, self.contexts.items.len },
        );
        var proc = std.ChildProcess.init(
            self.argv,
            self.allocator,
        );
        proc.stdin_behavior = .Pipe;
        proc.stdout_behavior = .Pipe;
        proc.stderr_behavior = .Pipe;

        // const c = @cImport({
        //     @cInclude("assert.h");
        //     @cInclude("stdio.h");
        //     @cInclude("string.h");
        //     @cInclude("stdlib.h");
        //     @cInclude("pty.h");
        //     @cInclude("utmp.h");
        // });
        // var master: c_int = 0;
        // const name = try std.heap.page_allocator.dupeZ(u8, "test");
        // const p = c.forkpty(
        //     master,
        //     name,
        //     null,
        //     null,
        // );
        // std.log.warn("pty: {any}\nmaster: {any}\n", .{p,master});

        ctx.* = .{
            .manager = self,
            .userName = userName,
            .channel = self.channel,
            // used in subscribe()
            .subscribeArgs = .{
                .channel = self.channel,
                .force_text = true,
                .context = ctx,
            },
            .process = .{
                .proc = proc,
                .thread = try std.Thread.spawn(
                    .{},
                    runProcess,
                    .{ ctx, self.allocator },
                ),
            },
            // used in upgrade()
            .settings = .{
                .on_open = on_open_websocket,
                .on_close = on_close_websocket,
                .on_message = handle_websocket_message,
                .context = ctx,
            },
        };
        try self.contexts.append(ctx);
        return ctx;
    }
};

//
// Websocket Callbacks
//
fn on_open_websocket(context: ?*Context, handle: WebSockets.WsHandle) void {
    if (context) |ctx| {
        _ = WebsocketHandler.subscribe(
            handle,
            &ctx.subscribeArgs,
        ) catch |err| {
            std.log.err(
                "Error opening websocket: {any}",
                .{err},
            );
            return;
        };

        std.log.info(
            "new websocket opened: user: {s} args: {any}",
            .{ ctx.userName, ctx.subscribeArgs },
        );
    }
}

fn on_close_websocket(context: ?*Context, uuid: isize) void {
    if (context) |ctx| {
        defer ctx.deinit();

        std.log.info("websocket closed: {d} {s}", .{ uuid, ctx.userName });
    }
}

fn handle_websocket_message(
    context: ?*Context,
    handle: WebSockets.WsHandle,
    message: []const u8,
    is_text: bool,
) void {
    _ = is_text;
    _ = handle;
    if (context) |ctx| {
        // send message
        // const buflen = 128; // arbitrary len
        // var buf: [buflen]u8 = undefined;

        ctx.process.proc.stdin.?.writeAll(message) catch {
            std.log.err("proc write error: {any}", .{ctx});
            return;
        };
    }
}

//
// HTTP stuff
//

pub fn on_upgrade(r: zap.SimpleRequest, target_protocol: []const u8) void {
    // make sure we're talking the right protocol
    if (!std.mem.eql(u8, target_protocol, "websocket")) {
        std.log.warn("received illegal protocol: {s}", .{target_protocol});
        r.setStatus(.bad_request);
        r.sendBody("400 - BAD REQUEST") catch unreachable;
        return;
    }
    var context = GlobalContextManager.newContext() catch |err| {
        std.log.err("Error creating context: {any}", .{err});
        return;
    };

    WebsocketHandler.upgrade(r.h, &context.settings) catch |err| {
        std.log.err("Error in websocketUpgrade(): {any}", .{err});
        return;
    };
    std.log.info("connection upgrade OK", .{});
}
