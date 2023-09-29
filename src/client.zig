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
    \\let msg = "Hello World from zig-js";
    \\
    \\function deref(ptr, len){
    \\  const memv = new Uint8Array(instance.memory.buffer, ptr, len);
    \\  return new TextDecoder().decode(memv);
    \\}
    \\
    \\console.log(msg);
    \\const ctx = canvas.getContext("2d");
    \\ctx.font = "48px serif";
    \\ctx.fillText(msg, 10, 50);
    \\
;

export fn main() void {
    eval(@intFromPtr(script.ptr), @as(usize, script.len));
}