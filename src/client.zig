const js = @import("zig-js");
const std = @import("std");

extern fn eval(ptr : usize, len: usize) u32;
extern fn log_wasm(ptr : usize, len: usize) void;

export fn tick(frame: u32, time: f32) void {
    _ = time;
    _ = frame;
}

export fn resize(width: u32, height: u32) void {
    _ = height;
    _ = width;
}

var logBuf:[9999]u8 = undefined;

fn do_log(comptime fmt: []const u8, args: anytype) void {
    const str = std.fmt.bufPrint(&logBuf, fmt, args) catch unreachable;
    log_wasm(@intFromPtr(str.ptr), str.len);
}

export fn main() void {
    do_log("WOLOLO", .{});
    do_log("WOLOLO", .{});
    const res = eval(@intFromPtr(script.ptr), @as(usize, script.len));
    do_log("WARNING: This int is the result of the last eval statement: {}", .{res});
}

const script =
    \\let msg = "Hello World from zig-js ";
    \\
    \\function deref(ptr, len){
    \\  const memv = new Uint8Array(instance.memory.buffer, ptr, len);
    \\  return new TextDecoder().decode(memv);
    \\}
    \\
    \\console.log(msg);
    \\document.title = msg;
    \\
    \\6969
;

const _ =
    \\const ctx = canvas.getContext("2d");
    \\ctx.font = "100px serif";
    \\ctx.textAlign = "center";
    \\
    \\var i = 0;
    \\var lastUpdate = Date.now();
    \\function animate() {
    \\  var now = Date.now();
    \\  var dt = now - lastUpdate;
    \\  lastUpdate = now;
    \\  requestAnimationFrame(animate);
    \\  ctx.clearRect(0, 0, canvas.width, canvas.height);
    \\  ctx.fillText(msg + i + " dps:  " + dt, canvas.width/3, 50);
    \\  instance.exports.tick(i,dt);
    \\  i += 1;
    \\}
    \\canvas.width = window.innerWidth;
    \\canvas.height = window.innerHeight;
    \\animate();
;
