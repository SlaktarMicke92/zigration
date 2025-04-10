const std = @import("std");
const pg = @import("pg");
const myzql = @import("myzql");

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
            std.log.info("Create migration table query", .{});
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
