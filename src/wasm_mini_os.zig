const std = @import("std");
pub const fs = @import("wasm_fs.zig");

pub const std_options = struct {
    pub const log_level = .info;
    pub fn logFn(
        comptime message_level: std.log.Level,
        comptime scope: @Type(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = args;
        _ = format;
        _ = scope;
        _ = message_level;
        // const level_txt = comptime message_level.asText();
        // const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
        // const stderr = std.io.getStdErr().writer();
        // std.debug.getStderrMutex().lock();
        // defer std.debug.getStderrMutex().unlock();
        // nosuspend stderr.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
    }
};

pub const os = @This();
pub const isize_t = i32;
pub const usize_t = u32;
pub const PATH_MAX = 4096;
pub const system = struct {
    pub const fd_t = usize_t;
    pub const uid_t = void;
    pub const pid_t = void;
    pub const gid_t = void;
    pub const ino_t = usize_t;
    pub const mode_t = usize_t;
    pub const timespec_t = usize_t;
    pub const IOV_MAX = 0;
    pub export const STDIN_FILENO: fd_t = 0;
    pub export const STDOUT_FILENO: fd_t = 1;
    pub export const STDERR_FILENO: fd_t = 2;
    pub const CLOCK = struct {
        pub const MONOTONIC = 0;
        pub const REALTIME = 1;
    };

    pub const timespec = struct {
        tv_sec: usize_t,
        tv_nsec: usize_t,
    };

    pub const AT = struct {
        pub const FDCWD = 3;
    };

    pub const S = struct {
        pub const IFMT = 0o0;
        pub const IFBLK = 0o1;
        pub const IFCHR = 0o2;
        pub const IFDIR = 0o3;
        pub const IFIFO = 0o4;
        pub const IFLNK = 0o5;
        pub const IFREG = 0o6;
        pub const IFSOCK = 0o7;
        pub fn ISCHR() void {}
    };

    pub const O = struct {
        pub const RDONLY = 0o0;
        pub const WRONLY = 0o1;
        pub const RDWR = 0o2;
        pub const CLOEXEC = 0o4;
    };

    pub const Stat = struct {
        mode: usize_t,
        ino: ino_t,
        size: u64,
        pub fn atime(self: Stat) timespec {
            _ = self;
            return .{
                .tv_sec = 0,
                .tv_nsec = 0,
            };
        }
        pub fn mtime(self: Stat) timespec {
            _ = self;
            return .{
                .tv_sec = 0,
                .tv_nsec = 0,
            };
        }
        pub fn ctime(self: Stat) timespec {
            _ = self;
            return .{
                .tv_sec = 0,
                .tv_nsec = 0,
            };
        }
    };

    pub const E = enum(u16) {
        SUCCESS,
        INTR,
        INVAL,
        FAULT,
        AGAIN,
        BADF, // can be a race condition.
        DESTADDRREQ, // `connect` was never called.
        DQUOT,
        FBIG,
        IO,
        NOSPC,
        PERM,
        PIPE,
        CONNRESET,
        BUSY,

        // Filesystem Errors
        ACCES,
        OVERFLOW,
        ISDIR,
        LOOP,
        MFILE,
        NAMETOOLONG,
        NFILE,
        NODEV,
        NOENT,
        NOMEM,
        NOTDIR,
        EXIST,
        OPNOTSUPP,
        TXTBSY,
        NOBUFS,
        TIMEDOUT,

        // Unknown
        UNKNOWN,
    };
    pub const sockaddr = struct {
        pub const in = 0;
    };
    pub fn write(fd: fd_t, ptr: [*]const u8, len: usize_t) isize_t {
        _ = len;
        _ = ptr;
        return switch (fd) {
            STDIN_FILENO => -1,
            STDOUT_FILENO => 0,
            STDERR_FILENO => 0,
            else => return -1,
        };
    }
    pub fn isatty(handle: fd_t) usize_t {
        _ = handle;
        return 0;
    }
    pub fn getenv(handle: [*:0]const u8) ?[*:0]const u8 {
        _ = handle;
        return null;
    }
    pub fn getErrno(u: ?isize_t) E {
        if (u) |it| {
            return @enumFromInt(it);
        }
        return .UNKNOWN;
    }
    pub fn exit(u: usize_t) noreturn {
        _ = u;
        while (true) {}
    }
    pub fn close(u: fd_t) isize_t {
        _ = u;
        return 0;
    }
    pub fn openat(fd: fd_t, path: [*:0]const u8, flags: usize_t, mode: mode_t) isize_t {
        _ = flags;
        _ = fd;
        if (mode != O.RDONLY) return -1;
        fs.initialize();

        const len = std.mem.indexOfSentinel(u8, 0, path);
        if (fs.map.get(path[0..len])) |entry| {
            fs.fd_table.appendAssumeCapacity(.{
                .asset = entry,
                .path = path[0..len],
            });
            return 0;
        } else {
            return -1;
        }
    }
    pub fn pipe() void {}
    pub fn fcntl() void {}
    pub fn fork() void {}
    pub fn execve() void {}
    pub fn ftruncate() void {}
    pub fn lseek() void {}
    pub fn pread() void {}
    pub fn read(fd: fd_t, ptr: [*]u8, len: usize_t) isize_t {
        if (fs.getFile(fd)) |entry| {
            var body = entry.getBody();
            @memcpy(
                ptr[0..len],
                body,
            );
            return 0;
        } else {
            return -1;
        }
    }
    pub fn readv() void {}
    pub fn pwrite() void {}
    pub fn pwritev() void {}
    pub fn pwrite_sym() void {}
    pub fn writev() void {}
    pub fn fsync() void {}
    pub fn fstat(fd: fd_t, s: *Stat) ?isize_t {
        _ = s;
        _ = fd;
        return null;
    }
};
