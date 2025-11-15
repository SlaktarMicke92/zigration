//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const pg = @import("pg");

const local_fs = @import("local_fs.zig");
const consts = @import("consts.zig");
const Database = @import("Database.zig");
const DatabaseType = @import("Database.zig").DatabaseType;

const ZigrationError = error{
    DatabaseUriParse,
    UnsupportedScheme,
    DatabaseInit,
};

fn get_database(allocator: *std.mem.Allocator, database_uri: []const u8) ZigrationError!Database {
    const uri = std.Uri.parse(database_uri) catch |err| {
        std.log.err("{}", .{err});
        return ZigrationError.DatabaseUriParse;
    };

    var database_type: DatabaseType = undefined;

    if (std.mem.eql(u8, uri.scheme, "postgresql")) {
        std.log.debug("Initializing with postgres", .{});
        database_type = DatabaseType.postgres;
    } else if (std.mem.eql(u8, uri.scheme, "mariadb")) {
        std.log.debug("Initializing with mariadb", .{});
        database_type = DatabaseType.mariadb;
    } else if (std.mem.eql(u8, uri.scheme, "mysql")) {
        std.log.debug("Initializing with mysql", .{});
        database_type = DatabaseType.mysql;
    } else {
        std.log.err("database type '{s}'' not supported", .{uri.scheme});
        return ZigrationError.UnsupportedScheme;
    }

    return Database.init(allocator, database_type, uri) catch {
        return ZigrationError.DatabaseInit;
    };
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
        return;
    };
    defer allocator.free(database_uri);

    var db = get_database(&allocator, database_uri) catch {
        return;
    };
    defer db.deinit();

    std.log.debug("Got database connection up", .{});

    db.create() catch |err| {
        std.log.err("{}", .{err});
        return;
    };

    std.log.debug("Getting migrations", .{});
    const files = local_fs.ls(consts.MIGRATION_PATH, allocator) catch |err| {
        std.log.err("{}", .{err});
        return;
    };
    defer {
        for (files) |v| {
            allocator.free(v);
        }
        allocator.free(files);
    }

    std.log.debug("Getting file contents", .{});

    for (files, 0..) |file, index| {
        std.log.debug("File path: {s}", .{file});

        const file_contents = local_fs.get_contents_of_file(allocator, file) catch |err| {
            std.log.err("{}", .{err});
            return;
        };
        defer allocator.free(file_contents);

        db.run_migration(file_contents, index + 1) catch |err| {
            std.log.err("{}", .{err});
            return;
        };
    }

    std.log.info("Ran migrations", .{});
}
