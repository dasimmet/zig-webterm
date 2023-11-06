const std = @import("std");

pub const fs = struct {
    pub const fd_table_t = std.ArrayList(?asset_fs.EntryType);
    const asset_fs = @import("fs");
    const map = asset_fs.map();

    pub var fd_table: fd_table_t = undefined;
    pub var initialized = false;
    pub fn initialize() void {
        if (!initialized) {
            fd_table = fd_table_t.initCapacity(
                std.heap.page_allocator,
                std.math.maxInt(os.usize_t),
            ) catch @panic("OOM");
            initialized = true;
            while (fd_table.items.len < 3) {
                fd_table.appendAssumeCapacity(null);
            }
        }
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
    pub const CLOCK = enum(u16) {
        MONOTONIC,
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
        pub fn atime(self: Stat) void {
            _ = self;
        }
        pub fn mtime(self: Stat) void {
            _ = self;
        }
        pub fn ctime(self: Stat) void {
            _ = self;
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
        _ = fd;
        return -1;
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
            fs.fd_table.appendAssumeCapacity(entry);
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
        if (fs.fd_table.items.len < fd) return -1;
        const entry = fs.fd_table.items[fd].?;
        const body = entry.decompressBodyAlloc(std.heap.page_allocator) catch @panic("OOM");
        @memcpy(
            ptr[0..len],
            body,
        );
        return 0;
    }
    pub fn readv() void {}
    pub fn pwrite() void {}
    pub fn pwritev() void {}
    pub fn pwrite_sym() void {}
    pub fn writev() void {}
    pub fn fsync() void {}
    pub fn fstat() void {}
};
