const std = @import("std");
const builtin = @import("builtin");

/// run migrations
pub fn run() void {}

/// create files for comptime check?
pub fn prepare() void {}

test "get environment variable" {
    // THIS NEEDS TEST_ENV_VAR SET
    if (builtin.target.os.tag == .linux) {
        const argv = [_][*:0]const u8{ "export", "TEST_ENV_VAR=lel" };
        std.os.linux.execve("/bin/sh", argv, null);
        const env = try std.process.getEnvVarOwned(std.testing.allocator, "TEST_ENV_VAR");
        defer std.testing.allocator.free(env);
        try std.testing.expect(std.mem.eql(u8, "lel", env));
    }
}
