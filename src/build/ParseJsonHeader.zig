const std = @import("std");

var buf: [4096]u8 = undefined;

pub fn json2Zon(Jvalue: std.json.Value, writer: anytype, indent: usize) !void {
    switch (Jvalue) {
        .null => {
            _ = try writer.write("null");
        },
        .bool => |v| {
            _ = try writer.print("{any}", .{v});
        },
        .integer => |v| {
            _ = try writer.print("{d}", .{v});
        },
        .float => |v| {
            try writer.print("{d}", .{v});
        },
        .number_string => |v| {
            try writer.print("{s}", .{v});
        },
        .string => |v| {
            try writer.print("\"{}\"", .{std.zig.fmtEscapes(v)});
        },
        .array => |v| {
            _ = try writer.write(".{\n");
            for (v.items) |entry| {
                try json2Zon(entry, writer, indent+1);
                _ = try writer.write(",\n");
            }
            _ = try writer.write("}\n");
        },
        .object => |v| {
            // array_list.ArrayListAligned(json.dynamic.Value,null)
            _ = try writer.write(".{\n");
            var iter = v.iterator();
            while (iter.next()) |entry| {
                _ = try writer.print(".@\"{}\"=", .{std.zig.fmtEscapes(entry.key_ptr.*)});
                try json2Zon(entry.value_ptr.*, writer, indent+1);
                _ = try writer.write(",\n");
            }
            _ = try writer.write("}");
        },
    }
}

inline fn parseJsonComptime(comptime p: []const u8) std.json.Value {
    var buf_alloc = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = buf_alloc.allocator();

    const json = @embedFile(p);

    return std.json.parseFromSliceLeaky(
        std.json.Value,
        allocator,
        json,
        .{},
    ) catch @panic("WOLOLO");
}
