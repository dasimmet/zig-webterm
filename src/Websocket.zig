const std = @import("std");
const zap = @import("zap");
const WebSockets = zap.WebSockets;

// global variables, yeah!
pub var GlobalContextManager: ContextManager = undefined;
const WebsocketHandler = WebSockets.Handler(Context);

const Context = struct {
    manager: *ContextManager,
    connected: bool = true,
    userName: []const u8,
    channel: []const u8,
    process: std.ChildProcess = undefined,
    // we need to hold on to them and just re-use them for every incoming
    // connection
    subscribeArgs: WebsocketHandler.SubscribeArgs,
    settings: WebsocketHandler.WebSocketSettings,
    thread: std.Thread,

    pub fn deinit(ctx: *Context) void {
        ctx.connected = false;
        ctx.process.stdin.?.close();
        ctx.process.stdout.?.close();
        ctx.process.stderr.?.close();
        ctx.thread.join();
    }
};

pub fn runProcess(self: *Context, allocator: std.mem.Allocator) !void {
    try self.process.spawn();
    var poller = std.io.poll(allocator, enum { stdout, stderr }, .{
        .stdout = self.process.stdout.?,
        .stderr = self.process.stderr.?,
    });
    defer poller.deinit();

    var buf: [4096]u8 = undefined;
    while (try poller.poll()) {
        if (poller.fifo(.stdout).count > 0) {
            const fifo = poller.fifo(.stdout);
            const msg_len = try fifo.reader().read(&buf);
            const message = buf[0..msg_len];

            WebsocketHandler.publish(.{ .channel = self.channel, .message = message });
            // std.log.info("stdout:{s}", .{message});
        }
        if (poller.fifo(.stderr).count > 0) {
            const fifo = poller.fifo(.stderr);
            const msg_len = try fifo.reader().read(&buf);
            const message = buf[0..msg_len];

            WebsocketHandler.publish(.{ .channel = self.channel, .message = message });
            // std.log.info("stderr:{s}", .{message});
        }

        if (!self.connected) {
            const term = try self.process.kill();
            std.debug.print("Process exited with status {}\n", .{term});
        }
    }
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
            .process = proc,
            // used in upgrade()
            .settings = .{
                .on_open = on_open_websocket,
                .on_close = on_close_websocket,
                .on_message = handle_websocket_message,
                .context = ctx,
            },
            .thread = try std.Thread.spawn(
                .{},
                runProcess,
                .{ ctx, self.allocator },
            ),
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
        // say hello
        var buf: [2048]u8 = undefined;
        const message = std.fmt.bufPrint(
            &buf,
            "{s} joined the chat with args {any}\n",
            .{ ctx.userName, ctx.subscribeArgs },
        ) catch @panic("bufPrint error");

        std.log.info("new websocket opened: {s}", .{message});
    }
}

fn on_close_websocket(context: ?*Context, uuid: isize) void {
    _ = uuid;
    if (context) |ctx| {
        ctx.deinit();
        // say goodbye
        var buf: [128]u8 = undefined;
        const message = std.fmt.bufPrint(
            &buf,
            "{s} left the chat.\r\n",
            .{ctx.userName},
        ) catch unreachable;

        // send notification to all others
        WebsocketHandler.publish(.{
            .channel = ctx.channel,
            .message = message,
        });
        std.log.info("websocket closed: {s}", .{message});
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

        ctx.process.stdin.?.writeAll(message) catch {
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
