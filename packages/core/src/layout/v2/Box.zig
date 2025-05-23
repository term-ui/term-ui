const mod = @import("mod.zig");
const std = @import("std");

size: mod.CSSPoint = .{ .x = 0, .y = 0 },
const Self = @This();

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try writer.print("[w: {d} h: {d}]", .{ self.size.x, self.size.y });
}
