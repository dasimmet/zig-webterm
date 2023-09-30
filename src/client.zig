const js = @import("zig-js");

// export fn set_title() void {
//     set_title_() catch unreachable;
// }

// export fn alert() void {
//     alert_() catch unreachable;
// }

// fn set_title_() !void {
//     const doc = try js.global.get(js.Object, "document");
//     defer doc.deinit();

//     try doc.set("title", js.string("Hello!"));
// }

// fn alert_() !void {
//     try js.global.call(void, "alert", .{js.string("Hello, world!")});
// }
extern fn eval(ptr : usize, len: usize) void;

const script =
    \\let canvas = document.getElementById("canvas");
    \\let msg = "Hello World from zig-js ";
    \\
    \\function deref(ptr, len){
    \\  const memv = new Uint8Array(instance.memory.buffer, ptr, len);
    \\  return new TextDecoder().decode(memv);
    \\}
    \\
    \\console.log(msg);
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

export fn tick(frame: u32, time: f32) void {
    _ = time;
    _ = frame;
}

export fn resize(width: u32, height: u32) void {
    _ = height;
    _ = width;
}

export fn main() void {
    eval(@intFromPtr(script.ptr), @as(usize, script.len));
}