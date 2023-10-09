//! This is me having fun with the zig build system.
//!

pub const MyBuild = @This();
pub const Step = struct {
    //! My Custom Build Steps
    //!

    pub const Download = @import("Step/Download.zig");
    pub const JZon = @import("Step/JZon.zig");
    pub const Compress = @import("Step/Compress.zig");
    pub const Serve = @import("Step/Serve.zig");
};
pub const RecursiveDirIterator = @import("RecursiveDirIterator.zig");
pub const CompressHeader = @import("CompressHeader.zig");
pub const JsonToZon = @import("JsonToZon.zig");
pub const std = @import("std");
pub const builtin = @import("builtin");