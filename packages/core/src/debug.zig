const std = @import("std");
const builtin = @import("builtin");

pub fn assert(condition: bool, comptime fmt: []const u8, args: anytype) void {
    if (builtin.mode != .ReleaseFast) if (!condition) {
        std.debug.panic(fmt, args);
    };
}
