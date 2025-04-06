const std = @import("std");
const pg = @import("pg");
const myzql = @import("myzql");

const Database = @This();

const DatabaseType = enum {
    postgres,
    mysql,
    mariadb,
};

const DatabaseDriver = union(DatabaseType) {
    postgres: pg,
    mysql: myzql,
    mariadb: myzql,
};

db: DatabaseDriver,

pub const DatabaseError = error{
    ConnectionError,
};

pub fn open(self: Database) void {
    switch (self.db) {
        .postgres => {
            std.log.info("Opening connection with postgres", .{});
        },
        .mariadb, .mysql => {
            std.log.info("Opening connection with mariadb/mysql", .{});
        },
    }
}

/// anytype for database/transaction/pool object?
pub fn create() void {}
