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

        // Alternatively:
        var file_with_path = try allocator.alloc(u8, path.len + file.name.len);
        defer allocator.free(file_with_path);
        @memcpy(file_with_path[0..path.len], path);
        @memcpy(file_with_path[path.len..], file.name);
        try files.append(try allocator.dupe(u8, file_with_path));
    }

    return try files.toOwnedSlice();
}

/// Get contents of file
pub fn get_contents_of_file(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    // Open the file
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Read the contents
    const buffer_size = 2000;
    const file_buffer = try file.readToEndAlloc(allocator, buffer_size);

    return file_buffer;
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

    try std.testing.expect(std.mem.eql(u8, "Database.zig", files[0]));
}
