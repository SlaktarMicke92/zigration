//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const pg = @import("pg");

const hash = @import("hash.zig");
const local_fs = @import("local_fs.zig");
const Database = @import("Database.zig");

pub export fn run_migrations() void {
    var db = Database{ .db = .{ .postgres = pg{} } };
    db.open();
}
