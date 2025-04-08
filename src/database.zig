const std = @import("std");
const pg = @import("pg");
const myzql = @import("myzql");

const Database = @This();

const DatabaseType = enum {
    postgres,
    mysql,
    mariadb,
};

const DatabaseConnection = union(DatabaseType) {
    postgres: pg.Conn,
    mysql: myzql.conn.Conn,
    mariadb: myzql.conn.Conn,
};

db_type: DatabaseType,
uri: std.Uri,

pub const DatabaseError = error{
    ConnectionError,
};

pub fn open(self: Database, allocator: std.mem.Allocator) !DatabaseConnection {
    switch (self.db_type) {
        .postgres => {
            std.log.info("Opening connection with postgres", .{});
            return DatabaseConnection{ .postgres = try pg.Conn.openAndAuthUri(allocator, self.uri) };
        },
        .mariadb => {
            std.log.info("Opening connection with mariadb", .{});
            return DatabaseConnection{ .mariadb = try myzql.conn.Conn.init(allocator, &.{
                .username = "sentinel-zero-string",
                .password = "sentinel-zero-string",
                .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3306),
                .database = "sentinel-zero-string",
            }) };
        },
        .mysql => {
            std.log.info("Opening connection with mysql", .{});
            return DatabaseConnection{ .mysql = try myzql.conn.Conn.init(allocator, &.{
                .username = "sentinel-zero-string",
                .password = "sentinel-zero-string",
                .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3306),
                .database = "sentinel-zero-string",
            }) };
        },
    }
}

pub fn deinit(self: *Database, db_conn: *DatabaseConnection) void {
    switch (db_conn.*) {
        .postgres => |*conn| conn.*.deinit(),
        .mysql, .mariadb => |*conn| conn.*.deinit(),
    }
    self.* = undefined;
}

/// anytype for database/transaction/pool object?
pub fn create() void {}
