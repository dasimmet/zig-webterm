const std = @import("std");
pub const zig = @import("zig");
pub const os = @import("wasm_mini_os.zig");

// pub const main = zig.main;

pub fn main() !void {
    const cwd = std.fs.cwd();
    const fd = try cwd.openFile("index.html", .{});
    defer fd.close();

    var buf: [4096]u8 = undefined;
    const a = try fd.read(buf[0..]);
    std.log.warn("err: {any}", .{a});
}
