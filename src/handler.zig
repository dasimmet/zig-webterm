const Handler = @This();
const std = @import("std");
const Server = std.http.Server;

allocator: std.mem.Allocator,

pub fn handleRequest(Self: *Handler, res: *Server.Response) !void{
    // std.debug.print("Request: {any}\n", .{res});
    const body = try res.reader().readAllAlloc(Self.allocator, 8192);
    defer Self.allocator.free(body);

    res.transfer_encoding = .chunked;
    Self.getFile(res) catch return Self.notFound(res);
}

pub fn getFile(Self: *Handler, res: *Server.Response) !void {
    
    const cwd = std.fs.cwd();
    std.log.debug("{s}\n", .{res.request.target});
    var route = std.mem.trimLeft(u8, res.request.target, "/");
    if (route.len == 0){
        route = "index.html";
    }
    var f = cwd.openFile(route, .{}) catch {
        return Self.notFound(res);
    };
    defer f.close();

    var in_stream = f.reader();

    if (std.mem.endsWith(u8, route, ".html")){
        try res.headers.append("content-type", "text/html");
    } else {
        try res.headers.append("content-type", "text/plain");
    }
    try res.do();
    var buffer: [4096]u8 = undefined;
    while (true) {
        const count = in_stream.read(&buffer) catch break;
        if (count <= 0) break;
        try res.writeAll(buffer[0..count]);
    // try res.writeAll("World!\n");
    
    }
    try res.finish();

}

pub fn notFound(Self: *Handler, res: *Server.Response) !void{
    _ = Self;
    try res.headers.append("content-type", "text/plain");
    res.status = .not_found;
    try res.do();
    try std.fmt.format(res.writer(), "Not Found: {s}\n", .{res.request.target});
    try res.finish();
}