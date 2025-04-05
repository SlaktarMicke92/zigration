//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const hash = @import("hash.zig");
const local_fs = @import("local_fs.zig");

pub export fn run_migrations(a: i32, b: i32) i32 {
    return a + b;
}
