const std = @import("std");
const zigration = @import("zigration.zig");

pub fn main() void {
    std.log.debug("Importing zigration thus testing compile", .{});
    zigration.run();
    std.log.debug("Done", .{});
}
