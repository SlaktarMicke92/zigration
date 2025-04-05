const std = @import("std");

pub fn compare(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn create(value: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(value, &out, .{});
    return out;
}

test "compare same" {
    const a = create("hello");
    const b = create("hello");
    try std.testing.expect(compare(&a, &b));
}

test "compare different" {
    const a = create("hello");
    const b = create("world");
    try std.testing.expect(!compare(&a, &b));
}
