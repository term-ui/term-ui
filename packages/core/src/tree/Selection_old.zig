const std = @import("std");
const NodeId = @import("Node.zig").NodeId;
const Tree = @import("Tree.zig");
const Self = @This();

ranges: std.ArrayListUnmanaged(Range) = .{},
allocator: std.mem.Allocator,

const Direction = enum {
    none,
    forward,
    backward,
};
const Type = enum {
    none,
    range,
};
pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .allocator = allocator,
    };
}
pub fn deinit(self: *Self) void {
    self.ranges.deinit(self.allocator);
}

const Range = struct {
    anchor_node: NodeId,
    anchor_offset: usize,
    focus_node: NodeId,
    focus_offset: usize,
    direction: Direction,

    pub fn start(self: *Range) NodeId {
        return if (self.direction == .forward) self.anchor_node else self.focus_node;
    }
    pub fn end(self: *Range) NodeId {
        return if (self.direction == .forward) self.focus_node else self.anchor_node;
    }
};

pub fn addRange(self: *Self, range: Range) !void {
    try self.ranges.append(self.allocator, range);
}
pub fn removeRange(self: *Self, range_index: usize) void {
    self.ranges.orderedRemove(range_index);
}

pub fn removeAllRanges(self: *Self) void {
    self.ranges.clearRetainingCapacity();
}
pub fn extend(self: *Self, tree: *Tree, range_index: usize, node_id: NodeId, offset: ?usize) !void {
    if (range_index >= self.ranges.items.len) {
        std.debug.panic("Range index out of bounds: {d} >= {d}", .{ range_index, self.ranges.items.len });
    }
    const range = self.ranges.items[range_index];

    // Let oldAnchor and oldFocus be the this's anchor and focus, and let newFocus be the boundary point (node, offset).
    const oldAnchor = range.anchor_node;
    const oldAnchorOffset = range.anchor_offset;
    const newFocus = node_id;
    const newFocusOffset = offset orelse 0;

    // When extending, we keep the anchor fixed and only move the focus
    // Let newRange be a new range
    var newRange = Range{
        .anchor_node = oldAnchor,
        .anchor_offset = oldAnchorOffset,
        .focus_node = newFocus,
        .focus_offset = newFocusOffset,
        .direction = .none,
    };

    // If node's root is not the same as the this's range's root, set newRange's start and end to newFocus.
    const sameTree = (try tree.getLowestCommonAncestor(oldAnchor, newFocus)) != null;
    if (!sameTree) {
        newRange.anchor_node = newFocus;
        newRange.anchor_offset = newFocusOffset;
        newRange.focus_node = newFocus;
        newRange.focus_offset = newFocusOffset;
        newRange.direction = .none;
    } else {
        // Direction is determined by whether newFocus is before oldAnchor
        if (try tree.isNodeBefore(newFocus, oldAnchor) or
            (newFocus == oldAnchor and newFocusOffset < oldAnchorOffset))
        {
            newRange.direction = .backward;
        } else {
            newRange.direction = .forward;
        }
    }

    self.ranges.items[range_index] = newRange;
}
test "Selection.extend extends backward and forward on direct siblings" {
    const testing = std.testing;
    var selection = Self.init(testing.allocator);
    defer selection.deinit();

    var tree = try Tree.init(testing.allocator);
    defer tree.deinit();

    const root = try tree.createNode();
    const child_a = try tree.createNode();
    const child_b = try tree.createNode();
    const child_c = try tree.createNode();
    const child_d = try tree.createNode();

    try tree.appendChild(root, child_a);
    try tree.appendChild(root, child_b);
    try tree.appendChild(root, child_c);
    try tree.appendChild(root, child_d);

    try selection.addRange(.{
        .anchor_node = child_a,
        .anchor_offset = 0,
        .focus_node = child_a,
        .focus_offset = 0,
        .direction = .none,
    });
    try std.testing.expectEqual(selection.ranges.items.len, 1);

    try selection.extend(&tree, 0, child_c, null);
    try testing.expectEqual(selection.ranges.items[0].direction, .forward);

    selection.removeAllRanges();
    try selection.addRange(.{
        .anchor_node = child_c,
        .anchor_offset = 0,
        .focus_node = child_c,
        .focus_offset = 0,
        .direction = .none,
    });

    try selection.extend(&tree, 0, child_a, null);
    try testing.expectEqual(selection.ranges.items[0].direction, .backward);
    try testing.expectEqual(selection.ranges.items[0].anchor_node, child_c);
    try testing.expectEqual(selection.ranges.items[0].focus_node, child_a);
}

test "Selection.extend extends forward and backward through common ancestor" {
    const testing = std.testing;
    var selection = Self.init(testing.allocator);
    defer selection.deinit();

    var tree = try Tree.init(testing.allocator);
    defer tree.deinit();

    const root = try tree.createNode();
    const child_a = try tree.createNode();
    const child_b = try tree.createNode();
    const child_c = try tree.createNode();
    try tree.appendChild(root, child_a);
    try tree.appendChild(root, child_b);
    try tree.appendChild(root, child_c);

    const child_a_a = try tree.createNode();
    const child_a_b = try tree.createNode();
    try tree.appendChild(child_a, child_a_a);
    try tree.appendChild(child_a, child_a_b);

    const child_c_a = try tree.createNode();
    const child_c_b = try tree.createNode();
    const child_c_c = try tree.createNode();
    _ = child_c_c; // autofix
    try tree.appendChild(child_c, child_c_a);
    try tree.appendChild(child_c, child_c_b);

    try selection.addRange(.{
        .anchor_node = child_a_b,
        .anchor_offset = 0,
        .focus_node = child_a_b,
        .focus_offset = 0,
        .direction = .none,
    });

    try selection.extend(&tree, 0, child_c_b, null);
    try testing.expectEqual(selection.ranges.items[0].direction, .forward);
    try testing.expectEqual(selection.ranges.items[0].anchor_node, child_a_b);
    try testing.expectEqual(selection.ranges.items[0].focus_node, child_c_b);
    selection.removeAllRanges();
    try selection.addRange(.{
        .anchor_node = child_c_b,
        .anchor_offset = 0,
        .focus_node = child_c_b,
        .focus_offset = 0,
        .direction = .none,
    });

    try selection.extend(&tree, 0, child_a_b, null);
    try testing.expectEqual(selection.ranges.items[0].direction, .backward);
    try testing.expectEqual(selection.ranges.items[0].anchor_node, child_c_b);
    try testing.expectEqual(selection.ranges.items[0].focus_node, child_a_b);
}
