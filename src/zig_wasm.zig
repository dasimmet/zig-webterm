const std = @import("std");
pub const zig = @import("zig");
pub const os = @import("wasm_mini_os.zig");
pub const std_options = os.std_options;

// pub const main = zig.main;
pub const main = test_main;

pub fn test_main() !void {
    const cwd = std.fs.cwd();
    const fd = try cwd.openFile("index.html", .{});
    defer fd.close();

    const fd2 = try std.fs.openDirAbsolute("index.html", .{});
    _ = fd2;

    _ = try fd.stat();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var buf = try fd.readToEndAlloc(allocator, std.math.maxInt(os.usize_t));
    defer allocator.free(buf);

    std.log.warn("err: {any}", .{buf});
}
