const std = @import("std");

const database = @import("database.zig");

/// run migrations
pub fn run() void {}

/// create files for comptime check?
pub fn prepare() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{});
    const allocator = gpa.allocator();
    defer gpa.deinit();
    const env = try std.process.getEnvVarOwned(std.testing.allocator, "DATABASE_URL");
    defer allocator.free(env);
}

test "get environment variable" {
    // THIS NEEDS DATABASE_URL SET
    const env = try std.process.getEnvVarOwned(std.testing.allocator, "DATABASE_URL");
    defer std.testing.allocator.free(env);
    try std.testing.expect(std.mem.eql(u8, "lel", env));
}
