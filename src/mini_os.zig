pub const os = @This();
pub const isize_t = i32;
pub const usize_t = u32;
pub const system = struct {
    pub const fd_t = isize_t;
    pub const ino_t = usize_t;
    pub const mode_t = usize_t;
    pub const timespec_t = usize_t;
    pub const IOV_MAX = 0;
    pub export const STDIN_FILENO: fd_t = 0;
    pub export const STDOUT_FILENO: fd_t = 1;
    pub export const STDERR_FILENO: fd_t = 2;
    pub const AT = struct {
        pub const FDCWD = 3;
    };
    pub const S = struct {
        pub fn ISCHR() void {}
    };
    pub const O = struct {
        pub const RDONLY = 0o0;
        pub const WRONLY = 0o1;
        pub const RDWR = 0o2;
        pub const CLOEXEC = 0o4;
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
        UNKNOWN,
    };
    pub const Stat = struct {
        pub fn atime(self: Stat) void {
            _ = self;
        }
        pub fn mtime(self: Stat) void {
            _ = self;
        }
    };
    pub const sockaddr = struct {
        pub const in = 0;
    };
    pub extern "imports" fn write(
        fd: fd_t,
        ptr: [*]const u8,
        len: fd_t,
    ) isize_t;
    pub fn isatty(handle: fd_t) usize_t {
        _ = handle;
        return 0;
    }
    pub fn getenv(handle: [*:0]const u8) ?[*:0]const u8 {
        _ = handle;
        return null;
    }
    pub fn getErrno(u: isize_t) E {
        _ = u;
        return .SUCCESS;
    }
    pub fn exit(u: usize_t) noreturn {
        _ = u;
        while (true) {}
    }
    pub fn open() void {}
    pub fn close(u: fd_t) isize_t {
        _ = u;
        return 0;
    }
    pub fn ftruncate() void {}
    pub fn lseek() void {}
    pub fn pread() void {}
    pub fn read() void {}
    pub fn readv() void {}
    pub fn pwrite() void {}
    pub fn pwritev() void {}
    pub fn pwrite_sym() void {}
    pub fn writev() void {}
    pub fn fstat() void {}
};
