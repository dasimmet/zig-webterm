pub const zig_js = @import("zig-js");
pub const std = @import("std");
// an example wasm client that can run eval on the js side

// const _ = std.testing.refAllDecls(js);
pub const ext = struct {
    pub extern "imports" fn eval(ptr: usize, len: usize) u32;
    pub extern "imports" fn log_wasm(level: usize, ptr: usize, len: usize) void;
    pub extern "imports" fn panic_wasm() noreturn;
};

export fn tick(frame: u32, time: f32) void {
    _ = time;
    _ = frame;
}

export fn resize(width: u32, height: u32) void {
    _ = height;
    _ = width;
}

var logBuf: [256]u8 = undefined;

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, code: ?usize) noreturn {
    _ = code;
    std.log.err("Panic: {s}\nTrace:\n{any}\n", .{ msg, trace });
    ext.panic_wasm();
}
pub const std_options = struct {
    pub fn logFn(
        comptime message_level: std.log.Level,
        comptime scope: @Type(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = scope;

        const str = std.fmt.bufPrint(&logBuf, format, args) catch @panic("Log Buffer Overflow");
        ext.log_wasm(@intFromEnum(message_level), @intFromPtr(str.ptr), str.len);
    }
};

fn do_log(comptime fmt: []const u8, args: anytype) void {
    std.log.info(fmt, args);
}

pub fn eval_str(source: []const u8) u32 {
    return ext.eval(
        @intFromPtr(source.ptr),
        @as(usize, source.len),
    );
}
export fn main() void {
    std.log.debug("DEBUG", .{});
    std.log.info("INFO", .{});
    std.log.warn("WARN", .{});
    std.log.err("ERR", .{});
    // std.log.info("{s}{s}", .{script,canvas_script});
    const res = eval_str(hello_world_script);
    std.log.info("This int is the result of the last eval statement: {}", .{res});
}

const hello_world_script =
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
    \\42
;

const canvas_script =
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
