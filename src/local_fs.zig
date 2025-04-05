const std = @import("std");

/// REMEMBER to iterate through all items in list
/// when freeing memory, see test.
pub fn ls(path: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var files = std.ArrayList([]const u8).init(allocator);
    errdefer files.deinit();

    // Add all files names in the src folder to `files`
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();
    while (try it.next()) |file| {
        if (file.kind != .file) {
            continue;
        }
        try files.append(try allocator.dupe(u8, file.name));
    }

    return try files.toOwnedSlice();
}

test "read src" {
    // Get files from path
    const files = try ls("src", std.testing.allocator);
    // Defer free memory as it has been allocated from ArrayList
    defer {
        for (files) |v| {
            std.testing.allocator.free(v);
        }
        std.testing.allocator.free(files);
    }

    try std.testing.expect(std.mem.eql(u8, "database.zig", files[0]));
}
