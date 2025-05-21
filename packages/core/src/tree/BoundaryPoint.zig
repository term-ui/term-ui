const Node = @import("./Node.zig");
const std = @import("std");
const Order = std.math.Order;

const Self = @This();

node_id: Node.NodeId,
offset: u32,

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: std.io.AnyWriter) !void {
    _ = fmt;
    _ = options;
    try writer.print("BP({d}, {d})", .{ self.node_id, self.offset });
}
