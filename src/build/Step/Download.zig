const std = @import("std");
const builtin = @import("builtin");
pub const JsonToZon = @import("../JsonToZon.zig");
pub const JsonToZonLiteral = @embedFile("../JsonToZon.zig");

step: std.build.Step,
url: std.build.LazyPath,
output_dir: std.Build.GeneratedFile,
output_file: std.Build.GeneratedFile,
max_file_size: usize = 1073741824,
json_module: JsonModule = .DontBuild,

const JsonModule = union(enum) {
    DontBuild,
    Build: std.Build.GeneratedFile,
};

const DownloadStep = @This();
const Self = DownloadStep;

pub fn init(
    b: *std.Build,
    url: std.build.LazyPath,
    name: []const u8,
) *Self {
    var step = std.build.Step.init(.{
        .name = name,
        .owner = b,
        .id = std.build.Step.Id.custom,
        .makeFn = make,
    });

    url.addStepDependencies(&step);

    const self: *@This() = b.allocator.create(@This()) catch {
        @panic("Alloc Error");
    };

    self.* = .{
        .step = step,
        .url = url,
        .output_dir = .{ .step = &self.step },
        .output_file = .{ .step = &self.step },
    };
    return self;
}

fn make(step: *std.build.Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    const b = step.owner;
    const allocator = b.allocator;
    var self = @fieldParentPtr(
        Self,
        "step",
        step,
    );
    const url = self.url.path;

    var man = b.cache.obtain();
    defer man.deinit();

    // _ = try man.addFile(
    //     @src().file,
    //     self.max_file_size,
    // );
    // man.hash.addBytes(step.name);
    man.hash.addBytes(url);
    man.hash.addBytes(@tagName(self.json_module));
    man.hash.addBytes(JsonToZonLiteral);

    const basename = std.fs.path.basename(url);
    // std.log.warn("Basename: {s}", .{basename});

    self.step.result_cached = try man.hit();
    const digest = man.final();

    self.output_dir.path = try b.global_cache_root.join(allocator, &.{
        "o", &digest,
    });

    self.output_file.path = try b.global_cache_root.join(allocator, &.{
        "o", &digest, basename,
    });
    // std.log.warn("out: {s}", .{self.output_file.path.?});

    b.global_cache_root.handle.makeDir("o") catch |err| {
        const trace = @errorReturnTrace();
        _ = trace;
        switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        }
    };

    std.fs.makeDirAbsolute(self.output_dir.path.?) catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => |e| return e,
        }
    };

    if (!self.step.result_cached) {
        b.global_cache_root.handle.makeDir("tmp") catch |err| {
            switch (err) {
                error.PathAlreadyExists => {},
                else => |e| return e,
            }
        };

        const dl_dir = try b.global_cache_root.join(
            allocator,
            &.{
                "tmp", &digest,
            },
        );
        defer allocator.free(dl_dir);

        const dl_file = try b.global_cache_root.join(
            allocator,
            &.{
                "tmp", &digest, basename,
            },
        );
        defer allocator.free(dl_file);

        // const cwd = std.fs.cwd();
        try std.fs.makeDirAbsolute(dl_dir);
        defer std.fs.deleteTreeAbsolute(dl_dir) catch {
            std.log.warn("Error Cleaning Dir: {s}", .{dl_dir});
            @panic("Error Cleaning Dir");
        };

        const argv = [_][]const u8{ "curl", "-OL", url };
        const cmd = try std.mem.join(b.allocator, " ", &argv);
        defer allocator.free(cmd);

        var proc = try std.ChildProcess.exec(.{
            .allocator = allocator,
            .argv = &argv,
            .max_output_bytes = self.max_file_size,
            .cwd = dl_dir,
        });
        defer allocator.free(proc.stderr);
        defer allocator.free(proc.stdout);

        if (proc.term != .Exited or proc.term.Exited != 0) {
            std.log.err(
                "Proc error: {s}\nTerm:{any}\nStderr:\n{s}\nStdout:\n{s}",
                .{ cmd, proc.term, proc.stderr, proc.stdout },
            );
            return error.ChildProcess;
        }
        std.fs.renameAbsolute(
            dl_file,
            self.output_file.path.?,
        ) catch |err| {
            std.log.err("Error renaming File: {s}", .{dl_file});
            return err;
        };
        try man.writeManifest();
    }
    if (self.json_module == .Build) {
        const json_path = try std.mem.join(
            allocator,
            "",
            &[_][]const u8{
                self.output_file.path.?,
                ".zig",
            },
        );
        std.log.warn("{s}", .{json_path});

        self.json_module.Build.path = json_path;

        const json_file = try std.fs.createFileAbsolute(
            json_path,
            .{},
        );
        defer json_file.close();

        const content = try std.fs.cwd().readFileAlloc(
            allocator,
            self.output_file.path.?,
            self.max_file_size,
        );
        defer allocator.free(content);
    
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            content,
            .{},
        );
        defer parsed.deinit();

        try JsonToZon.write(
            parsed.value,
            json_file.writer()
        );

        // _ = try json_file.write(ParseJsonHeader);

        // try json_file.writer().print(
        //     "pub const value = parseJsonComptime(\"{}\");\n",
        //     .{
        //         std.zig.fmtEscapes(basename),
        //     },
        // );

        // parsed.value.dump();
    }
}

pub fn parseJson(self: *Self, b: *std.Build) *std.Build.Module {
    self.json_module = .{ .Build = .{
        .step = &self.step,
    } };

    return b.addModule(self.step.name, .{
        .source_file = .{
            .generated = &self.json_module.Build,
        },
    });
}

// fn randomHex(comptime size: usize, case: std.fmt.Case) []const u8 {
//     var rnd: [size]u8 = undefined;
//     std.crypto.random.bytes(&rnd);
//     const hex = std.fmt.bytesToHex(rnd, case);
//     return hex[0..];
// }
