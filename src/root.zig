//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const pg = @import("pg");

const hash = @import("hash.zig");
const local_fs = @import("local_fs.zig");
const Database = @import("Database.zig");
const DatabaseType = @import("Database.zig").DatabaseType;

const ZigrationError = error{
    DatabaseUriParse,
    UnsupportedScheme,
};

fn get_database(allocator: *std.mem.Allocator, database_uri: []const u8) ZigrationError!Database {
    const uri = std.Uri.parse(database_uri) catch |err| {
        std.log.err("{}", .{err});
        return ZigrationError.DatabaseUriParse;
    };

    var database_type: DatabaseType = undefined;

    if (std.mem.eql(u8, uri.scheme, "postgresql")) {
        std.log.info("Initializing with postgres", .{});
        database_type = DatabaseType.postgres;
    } else if (std.mem.eql(u8, uri.scheme, "mariadb")) {
        std.log.info("Initializing with mariadb", .{});
        database_type = DatabaseType.mariadb;
    } else if (std.mem.eql(u8, uri.scheme, "mysql")) {
        std.log.info("Initializing with mysql", .{});
        database_type = DatabaseType.mysql;
    } else {
        std.log.err("database type '{s}'' not supported", .{uri.scheme});
        return ZigrationError.UnsupportedScheme;
    }

    return Database.init(allocator, database_type, uri);
}

pub export fn run() void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    var allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Leak detected");
    }

    const database_uri = std.process.getEnvVarOwned(allocator, "DATABASE_URI") catch |err| {
        std.log.err("{}", .{err});
        std.process.exit(1);
    };
    defer allocator.free(database_uri);

    var db = get_database(&allocator, database_uri) catch {
        std.process.exit(1);
    };
    defer db.deinit();

    std.log.info("Got database connection up", .{});

    db.create() catch |err| {
        std.log.err("{}", .{err});
        std.process.exit(1);
    };
}
