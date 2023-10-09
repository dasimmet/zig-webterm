//! helpers writing a `.zig` file to a writer from a `std.json.Value`
//!

const std = @import("std");

/// iteration starter with depth 0 and to write header and footer
pub fn write(Jvalue: std.json.Value, writer: anytype, indent: usize) !void {
    try writer.writeAll("pub const data=");
    try convert(Jvalue, writer, indent, 0);
    try writer.writeAll(";\n");
}

// actual recursive writing function for json values
pub fn convert(
    Jvalue: std.json.Value,
    writer: anytype,
    indent: usize,
    depth: usize,
) !void {
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
                for (0..(depth + 1) * indent) |_| {
                    _ = try writer.write(" ");
                }
                try convert(
                    entry,
                    writer,
                    indent,
                    depth + 1,
                );
                _ = try writer.write(",\n");
            }
            for (0..(indent * depth)) |_| {
                _ = try writer.write(" ");
            }
            _ = try writer.write("}");
        },
        .object => |v| {
            // array_list.ArrayListAligned(json.dynamic.Value,null)
            _ = try writer.write(".{\n");
            var iter = v.iterator();
            while (iter.next()) |entry| {
                for (0..indent + 1) |_| {
                    _ = try writer.write(" ");
                }
                _ = try writer.print(".{}=", .{std.zig.fmtId(entry.key_ptr.*)});
                try convert(
                    entry.value_ptr.*,
                    writer,
                    indent,
                    depth + 1,
                );
                _ = try writer.write(",\n");
            }
            for (0..(indent * depth)) |_| {
                _ = try writer.write(" ");
            }
            _ = try writer.write("}");
        },
    }
}
