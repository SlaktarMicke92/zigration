const std = @import("std");
const root = @import("root.zig");

pub fn main() void {
    std.log.debug("Importing root thus testing compile", .{});
    root.run();
    std.log.debug("Done", .{});
}
