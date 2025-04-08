//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const pg = @import("pg");

const hash = @import("hash.zig");
const local_fs = @import("local_fs.zig");
const Database = @import("Database.zig");

pub export fn run() void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }
    const database_url = std.process.getEnvVarOwned(allocator, "DATABASE_URL") catch |err| {
        std.log.err("{}", .{err});
        std.process.exit(1);
    };
    defer allocator.free(database_url);

    const uri = std.Uri.parse(database_url) catch |err| {
        std.log.err("{}", .{err});
        std.process.exit(1);
    };

    var db = Database{ .db_type = .postgres, .uri = uri };
    var conn = db.open(allocator) catch |err| {
        std.log.err("{}", .{err});
        std.process.exit(1);
    };
    defer db.deinit(&conn);

    std.log.info("Got database connection up", .{});
}
