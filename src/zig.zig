const std = @import("std");
pub const zig = @import("zig");
pub const os = @import("mini_os.zig");

// pub const main = zig.main;

pub fn main() !void {
    const cwd = std.fs.cwd();
    const fd = try cwd.openFile("index.html", .{});
    defer fd.close();
}
