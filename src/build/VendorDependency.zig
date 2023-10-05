// Creates either a local dependency or 
// one from the package manager depending on a bool switch
// useful for working on changes in a local submodule,
// then pinning them in build.zig.zon once committed.

const std = @import("std");
const VendorDependency = @This();

const Self = @This();
pub fn init(
    b: *std.Build,
    vendor: bool,
    name: []const u8,
    relative_build_root: []const u8,
    comptime build_zig: type,
    args: anytype,
) *std.Build.Dependency {
    return if (vendor)
        b.anonymousDependency(relative_build_root, build_zig, args)
    else
        b.dependency(name, args);
}
