const std = @import("std");
const pg = @import("pg");
const myzql = @import("myzql");

const hash = @import("hash.zig");

const Database = @This();

pub const DatabaseType = enum {
    postgres,
    mysql,
    mariadb,
};

const DatabaseConnection = union(DatabaseType) {
    postgres: pg.Conn,
    mysql: myzql.conn.Conn,
    mariadb: myzql.conn.Conn,
};

pub const DatabaseError = error{
    ConnectionError,
};

db_connection: DatabaseConnection,
allocator: *std.mem.Allocator,

pub fn init(allocator: *std.mem.Allocator, db_type: DatabaseType, uri: std.Uri) Database {
    return Database{
        .db_connection = open(allocator, db_type, uri) catch |err| {
            std.log.err("{}", .{err});
            std.process.exit(1);
        },
        .allocator = allocator,
    };
}

fn open(allocator: *std.mem.Allocator, db_type: DatabaseType, uri: std.Uri) !DatabaseConnection {
    switch (db_type) {
        .postgres => {
            std.log.info("Opening connection with postgres", .{});
            return DatabaseConnection{ .postgres = try pg.Conn.openAndAuthUri(allocator.*, uri) };
        },
        .mariadb => {
            std.log.info("Opening connection with mariadb", .{});
            return DatabaseConnection{ .mariadb = try myzql.conn.Conn.init(allocator.*, &.{
                .username = "sentinel-zero-string",
                .password = "sentinel-zero-string",
                .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3306),
                .database = "sentinel-zero-string",
            }) };
        },
        .mysql => {
            std.log.info("Opening connection with mysql", .{});
            return DatabaseConnection{ .mysql = try myzql.conn.Conn.init(allocator.*, &.{
                .username = "sentinel-zero-string",
                .password = "sentinel-zero-string",
                .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3306),
                .database = "sentinel-zero-string",
            }) };
        },
    }
}

pub fn deinit(self: *Database) void {
    switch (self.db_connection) {
        .postgres => |*conn| conn.*.deinit(),
        .mysql, .mariadb => |*conn| conn.*.deinit(),
    }
    self.* = undefined;
}

pub fn create(self: *Database) !void {
    try self.begin();

    const query = switch (self.db_connection) {
        .postgres =>
        \\CREATE TABLE IF NOT EXISTS _zigration (
        \\zigration_id UUID PRIMARY KEY,
        \\check_sum CHAR(32),
        \\sequence SERIAL,
        \\created_at DATE DEFAULT CURRENT_DATE
        \\);
        ,
        .mariadb, .mysql =>
        \\CREATE TABLE IF NOT EXISTS _zigration (
        \\zigration_id UUID
        \\check_sum CHAR(32)
        \\sequence INT AUTO_INCREMENT
        \\created_at DATETIME DEFAULT CURRENT_DATE
        \\PRIMARY KEY zigration_id
        \\);
        ,
    };

    try self.execute(query, .{});
    try self.commit();

    std.log.info("Created zigration table", .{});
}

fn begin(self: *Database) !void {
    // Start transaction
    switch (self.db_connection) {
        .postgres => |*conn| {
            std.log.info("Begin postgres transaction", .{});
            try conn.*.begin();
        },
        else => {
            // No support for transactions
        },
    }
}

fn commit(self: *Database) !void {
    switch (self.db_connection) {
        .postgres => |*conn| {
            std.log.info("Commiting transaction", .{});
            try conn.*.commit();
        },
        else => {
            // no support for transactions
        },
    }
}

fn execute(self: *Database, query: []const u8, values: anytype) !void {
    switch (self.db_connection) {
        .postgres => |*conn| {
            std.log.info("executing query", .{});
            _ = conn.*.exec(query, values) catch |err| {
                if (conn.err) |pge| {
                    std.log.err("PG {s}\n", .{pge.message});
                }
                return err;
            };
        },
        .mariadb, .mysql => |*conn| {
            const prep = try conn.*.prepare(self.allocator.*, query);
            defer prep.deinit(self.allocator.*);
            const prep_stmt = try prep.expect(.stmt);
            _ = try conn.*.execute(&prep_stmt, values);
        },
    }
}

fn select_check_sum_by_sequence(self: *Database, check_sum_buffer: *[32]u8, sequence: usize) !void {
    switch (self.db_connection) {
        .postgres => |*conn| {
            const result = try conn.*.query(
                "SELECT check_sum FROM _zigration WHERE sequence = $1 LIMIT 1",
                .{sequence},
            );
            defer result.deinit();

            while (try result.next()) |row| {
                const check_sum = row.get([]u8, 0);
                @memcpy(check_sum_buffer[0..], check_sum);
            }
        },
        .mariadb, .mysql => |*conn| {
            _ = conn;
        },
    }
}

pub fn run_migration(self: *Database, query: []const u8, sequence: usize) !void {
    // Take in migrations from local_fs as parameter
    // Run every migration but first check if sequence exists in DB
    // and make a check_sum check against it.
    var check_sum_buffer: [32]u8 = std.mem.zeroes([32]u8);
    try self.select_check_sum_by_sequence(
        &check_sum_buffer,
        sequence,
    );

    try self.begin();

    try self.execute(query, .{});

    // Probably need sequence number for checking against database

    // No need for check_sum until query has been validated
    const check_sum = hash.create(query);

    // First if need to check if existing_check_sum even has a value
    if (std.mem.eql(u8, &check_sum_buffer, &std.mem.zeroes([32]u8))) {
        // Everything is fine, run migration
    } else if (std.mem.eql(u8, &check_sum_buffer, &check_sum)) {
        // Everything is fine, no need to run migration
        return;
    }

    // TODO: Need to add row to _zigration for migration

    try self.commit();
}
