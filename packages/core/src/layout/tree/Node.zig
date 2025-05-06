const std = @import("std");
const Style = @import("Style.zig");
const ArrayList = std.ArrayListUnmanaged;
const Layout = @import("Layout.zig");
const Point = @import("../point.zig").Point;
const AvailableSpace = @import("../compute/compute_constants.zig").AvailableSpace;
const build_options = @import("build_options");
const Node = @This();
const Cache = @import("Cache.zig");
const Tree = @import("Tree.zig");
const ComputedText = @import("../compute/text/ComputedText.zig");
const String = @import("String.zig");
pub const NodeKind = enum(u8) {
    node = 1,
    text = 2,
};

id: NodeId,
kind: NodeKind = .node,
parent: ?NodeId = null,
children: ArrayList(NodeId) = .{},
styles: Style,
unrounded_layout: Layout = .{},
layout: Layout = .{},
cache: Cache = .{},
text: String = .{},

scroll_offset: Point(f32) = .{
    .x = 0,
    .y = 0,
},
computed_text: ?ComputedText = null,
text_root_id: ?NodeId = null,
pub const NodeId = usize;
pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
    self.children.deinit(allocator);
    self.text.deinit(allocator);

    if (self.computed_text) |*computed_text| {
        computed_text.deinit();
    }
}
