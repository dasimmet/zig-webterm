pub const FIOBJ = usize;
pub const FIOBJ_T_NUMBER: c_int = 1;
pub const FIOBJ_T_NULL: c_int = 6;
pub const FIOBJ_T_TRUE: c_int = 22;
pub const FIOBJ_T_FALSE: c_int = 38;
pub const FIOBJ_T_FLOAT: c_int = 39;
pub const FIOBJ_T_STRING: c_int = 40;
pub const FIOBJ_T_ARRAY: c_int = 41;
pub const FIOBJ_T_HASH: c_int = 42;
pub const FIOBJ_T_DATA: c_int = 43;
pub const FIOBJ_T_UNKNOWN: c_int = 44;
pub const fiobj_type_enum = u8;

pub const struct_fio_str_info_s = extern struct {
    capa: usize,
    len: usize,
    data: [*c]u8,
};
pub const fio_str_info_s = struct_fio_str_info_s;

pub extern fn fio_ltocstr(c_long) fio_str_info_s;
pub extern fn http_mimetype_find(file_ext: [*c]u8, file_ext_len: usize) FIOBJ;
pub extern fn http_mimetype_register(file_ext: [*c]u8, file_ext_len: usize, mime_type_str: FIOBJ) void;
pub const fiobj_object_vtable_s = extern struct {
    class_name: [*c]const u8,
    dealloc: ?*const fn (FIOBJ, ?*const fn (FIOBJ, ?*anyopaque) callconv(.C) void, ?*anyopaque) callconv(.C) void,
    count: ?*const fn (FIOBJ) callconv(.C) usize,
    is_true: ?*const fn (FIOBJ) callconv(.C) usize,
    is_eq: ?*const fn (FIOBJ, FIOBJ) callconv(.C) usize,
    each: ?*const fn (FIOBJ, usize, ?*const fn (FIOBJ, ?*anyopaque) callconv(.C) c_int, ?*anyopaque) callconv(.C) usize,
    to_str: ?*const fn (FIOBJ) callconv(.C) fio_str_info_s,
    to_i: ?*const fn (FIOBJ) callconv(.C) isize,
    to_f: ?*const fn (FIOBJ) callconv(.C) f64,
};
pub extern const FIOBJECT_VTABLE_NUMBER: fiobj_object_vtable_s;
pub extern const FIOBJECT_VTABLE_FLOAT: fiobj_object_vtable_s;
pub extern const FIOBJECT_VTABLE_STRING: fiobj_object_vtable_s;
pub extern const FIOBJECT_VTABLE_ARRAY: fiobj_object_vtable_s;
pub extern const FIOBJECT_VTABLE_HASH: fiobj_object_vtable_s;
pub extern const FIOBJECT_VTABLE_DATA: fiobj_object_vtable_s;
pub fn fiobj_type_vtable(arg_o: FIOBJ) callconv(.C) [*c]const fiobj_object_vtable_s {
    var o = arg_o;
    while (true) {
        switch (@as(c_int, @bitCast(@as(c_uint, fiobj_type(o))))) {
            @as(c_int, 1) => return &FIOBJECT_VTABLE_NUMBER,
            @as(c_int, 39) => return &FIOBJECT_VTABLE_FLOAT,
            @as(c_int, 40) => return &FIOBJECT_VTABLE_STRING,
            @as(c_int, 41) => return &FIOBJECT_VTABLE_ARRAY,
            @as(c_int, 42) => return &FIOBJECT_VTABLE_HASH,
            @as(c_int, 43) => return &FIOBJECT_VTABLE_DATA,
            @as(c_int, 6), @as(c_int, 22), @as(c_int, 38), @as(c_int, 44) => return null,
            else => {},
        }
        break;
    }
    return null;
}

pub fn fiobj_type_name(o: FIOBJ) callconv(.C) [*c]const u8 {
    if ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) != 0)
        return "Number";
    if (((o != 0) and 
        ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) == 
        @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 0)))))) and
        ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) != 
        @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6)))))
    ) return fiobj_type_vtable(o).*.class_name;
    if (!(o != 0)) return "NULL";
    return "Primitive";
}


pub fn fiobj_type(arg_o: FIOBJ) callconv(.C) fiobj_type_enum {
    var o = arg_o;
    if (!(o != 0)) return @as(u8, @bitCast(@as(i8, @truncate(FIOBJ_T_NULL))));
    if ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) != 0) return @as(u8, @bitCast(@as(i8, @truncate(FIOBJ_T_NUMBER))));
    if ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) == @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) return @as(u8, @bitCast(@as(u8, @truncate(o))));
    if (true and ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) == @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 2)))))) return @as(u8, @bitCast(@as(i8, @truncate(FIOBJ_T_STRING))));
    if (true and ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) == @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4)))))) return @as(u8, @bitCast(@as(i8, @truncate(FIOBJ_T_HASH))));
    const t = @import("std").meta.alignment([*c]fiobj_type_enum);
    // const t_len = @as(?*anyopaque, @ptrFromInt(o & ~@as(usize, @bitCast(@as(c_long, @as(c_int, 7))))));
    return @as([*c]fiobj_type_enum, @ptrFromInt(t))[@as(c_uint, @intCast(@as(c_int, 0)))];
}

pub fn fiobj_obj2cstr(o: FIOBJ) callconv(.C) fio_str_info_s {
    if (!(o != 0)) {
        var ret: fio_str_info_s = fio_str_info_s{
            .capa = @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))),
            .len = @as(usize, @bitCast(@as(c_long, @as(c_int, 4)))),
            .data = @as([*c]u8, @ptrFromInt(@intFromPtr("null"))),
        };
        return ret;
    }
    if ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) != 0) return fio_ltocstr(@as(isize, @bitCast(o)) >> @as(@import("std").math.Log2Int(isize), @intCast(1)));
    if ((o & @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) == @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 6))))) {
        while (true) {
            switch (@as(c_int, @bitCast(@as(c_uint, @as(u8, @bitCast(@as(u8, @truncate(o)))))))) {
                @as(c_int, 6) => {
                    {
                        var ret: fio_str_info_s = fio_str_info_s{
                            .capa = @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))),
                            .len = @as(usize, @bitCast(@as(c_long, @as(c_int, 4)))),
                            .data = @as([*c]u8, @ptrFromInt(@intFromPtr("null"))),
                        };
                        return ret;
                    }
                },
                @as(c_int, 38) => {
                    {
                        var ret: fio_str_info_s = fio_str_info_s{
                            .capa = @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))),
                            .len = @as(usize, @bitCast(@as(c_long, @as(c_int, 5)))),
                            .data = @as([*c]u8, @ptrFromInt(@intFromPtr("false"))),
                        };
                        return ret;
                    }
                },
                @as(c_int, 22) => {
                    {
                        var ret: fio_str_info_s = fio_str_info_s{
                            .capa = @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))),
                            .len = @as(usize, @bitCast(@as(c_long, @as(c_int, 4)))),
                            .data = @as([*c]u8, @ptrFromInt(@intFromPtr("true"))),
                        };
                        return ret;
                    }
                },
                else => break,
            }
            break;
        }
    }
    return fiobj_type_vtable(o).*.to_str.?(o);
}