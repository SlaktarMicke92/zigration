const std = @import("std");

pub fn compare(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn create(value: []const u8, out: *[32]u8) void {
    std.crypto.hash.sha2.Sha256.hash(value, out, .{});
}

test "compare same" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    create("hello", &a);
    create("hello", &b);
    try std.testing.expect(compare(&a, &b));
}

test "compare different" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    create("hello", &a);
    create("world", &b);
    try std.testing.expect(!compare(&a, &b));
}
