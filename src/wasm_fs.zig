const std = @import("std");
const asset_fs = @import("fs");

pub const fd_table_t = std.ArrayList(File);
pub const File = struct {
    asset: ?asset_fs.EntryType = null,
    pos: usize = 0,
    decompressed_body: ?[]const u8 = null,
    path: ?[]const u8 = null,
    pub fn getBody(self: *File) []const u8 {
        if (self.decompressed_body == null) {
            self.decompressed_body = self.asset.?.decompressBodyAlloc(std.heap.page_allocator) catch @panic("OOM");
        }
        return self.decompressed_body.?;
    }
};

pub const map = asset_fs.map();
pub fn getFile(fd: usize) ?*File {
    if (fd_table.items.len < fd) return null;
    var file = &fd_table.items[fd - 1];
    _ = file.getBody();
    return file;
}

pub var fd_table: fd_table_t = undefined;
pub var initialized = false;
pub fn initialize() void {
    if (!initialized) {
        fd_table = fd_table_t.initCapacity(
            std.heap.page_allocator,
            std.math.maxInt(usize),
        ) catch @panic("OOM");
        initialized = true;
        while (fd_table.items.len < 3) {
            fd_table.appendAssumeCapacity(.{});
        }
    }
}
