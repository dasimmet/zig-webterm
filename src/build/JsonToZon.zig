const std = @import("std");

pub fn write(Jvalue: std.json.Value, writer: anytype) !void {
    try writer.writeAll("pub const data=");
    try convert(Jvalue, writer, 0);
    try writer.writeAll(";\n");
}

pub fn convert(Jvalue: std.json.Value, writer: anytype, indent: usize) !void {
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
                for (0..indent + 1) |_| {
                    _ = try writer.write("  ");
                }
                try convert(entry, writer, indent + 1);
                _ = try writer.write(",\n");
            }
            for (0..indent) |_| {
                _ = try writer.write("  ");
            }
            _ = try writer.write("}");
        },
        .object => |v| {
            // array_list.ArrayListAligned(json.dynamic.Value,null)
            _ = try writer.write(".{\n");
            var iter = v.iterator();
            while (iter.next()) |entry| {
                for (0..indent + 1) |_| {
                    _ = try writer.write("  ");
                }
                _ = try writer.print(".@\"{}\"=", .{std.zig.fmtEscapes(entry.key_ptr.*)});
                try convert(entry.value_ptr.*, writer, indent + 1);
                _ = try writer.write(",\n");
            }
            for (0..indent) |_| {
                _ = try writer.write("  ");
            }
            _ = try writer.write("}");
        },
    }
}