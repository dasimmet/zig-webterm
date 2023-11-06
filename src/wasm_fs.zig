const std = @import("std");
const asset_fs = @import("fs");

pub const fd_table_t = std.ArrayList(?asset_fs.EntryType);
pub const map = asset_fs.map();

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
            fd_table.appendAssumeCapacity(null);
        }
    }
}
