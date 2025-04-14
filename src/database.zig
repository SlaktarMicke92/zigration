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
    ConnectionFailed,
    MigrationConflict,
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
            std.log.debug("Opening connection with postgres", .{});
            return DatabaseConnection{ .postgres = try pg.Conn.openAndAuthUri(allocator.*, uri) };
        },
        .mariadb => {
            std.log.debug("Opening connection with mariadb", .{});
            return DatabaseConnection{ .mariadb = try myzql.conn.Conn.init(allocator.*, &.{
                .username = "sentinel-zero-string",
                .password = "sentinel-zero-string",
                .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3306),
                .database = "sentinel-zero-string",
            }) };
        },
        .mysql => {
            std.log.debug("Opening connection with mysql", .{});
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
        \\check_sum CHAR(64),
        \\sequence SERIAL,
        \\created_at DATE DEFAULT CURRENT_DATE
        \\);
        ,
        .mariadb, .mysql =>
        \\CREATE TABLE IF NOT EXISTS _zigration (
        \\zigration_id UUID
        \\check_sum CHAR(64)
        \\sequence INT AUTO_INCREMENT
        \\created_at DATETIME DEFAULT CURRENT_DATE
        \\PRIMARY KEY zigration_id
        \\);
        ,
    };

    try self.execute(query, .{});
    try self.commit();

    std.log.debug("Created zigration table", .{});
}

fn begin(self: *Database) !void {
    // Start transaction
    switch (self.db_connection) {
        .postgres => |*conn| {
            std.log.debug("Begin postgres transaction", .{});
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
            std.log.debug("Commiting transaction", .{});
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
            std.log.debug("Executing query", .{});
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

fn add_migration(self: *Database, check_sum: [32]u8) !void {
    const query = switch (self.db_connection) {
        .postgres =>
        \\INSERT INTO _zigration (zigration_id, check_sum)
        \\VALUES (gen_random_uuid(), $1);
        ,
        .mariadb, .mysql =>
        \\
        ,
    };

    try self.execute(query, .{&std.fmt.bytesToHex(check_sum, .upper)});
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
                _ = try std.fmt.hexToBytes(check_sum_buffer, check_sum);
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

    var new_check_sum: [32]u8 = undefined;
    hash.create(query, &new_check_sum);

    // First if need to check if existing_check_sum even has a value
    if (std.mem.eql(u8, &check_sum_buffer, &std.mem.zeroes([32]u8))) {
        // Everything is fine, run migration
    } else if (std.mem.eql(u8, &check_sum_buffer, &new_check_sum)) {
        // Everything is fine, no need to run migration
        std.log.info(
            "Migration with check sum {s} already applied, skipping...",
            .{std.fmt.bytesToHex(check_sum_buffer, .upper)},
        );
        return;
    } else {
        // Check sums are different, not good
        std.log.err(
            "Check sums for sequence: {d} are different. Stopping migrations.",
            .{sequence},
        );
        return DatabaseError.MigrationConflict;
    }

    std.log.info(
        "Applying migration: {d}, check_sum: {s}",
        .{ sequence, std.fmt.bytesToHex(new_check_sum, .upper) },
    );

    try self.begin();

    try self.execute(query, .{});

    try self.add_migration(new_check_sum);

    try self.commit();
}
