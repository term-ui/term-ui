const Node = @import("./Node.zig");
const Tree = @import("./Tree.zig");
const std = @import("std");
const Order = std.math.Order;

pub const BoundaryPoint = struct {
    node_id: Node.NodeId,
    offset: u32,
    // pub fn order(self: BoundaryPoint, tree: *Tree, other: BoundaryPoint) !Order {
    //     const node_a = self.node_id;
    //     const node_b = other.node_id;
    //     const offset_a = self.offset;
    //     const offset_b = other.offset;
    //     if (tree.getNode(node_a).root() != tree.getNode(node_b).root()) {
    //         // Assert: nodeA and nodeB have the same root.
    //         return error.NodesNotInSameTree;
    //     }
    //     // The position of a boundary point (nodeA, offsetA) relative to a boundary point (nodeB, offsetB) is before, equal, or after, as returned by these steps:

    //     // If nodeA is nodeB, then return equal if offsetA is offsetB, before if offsetA is less than offsetB, and after if offsetA is greater than offsetB.
    //     if (node_a == node_b) {
    //         if (offset_a == offset_b) {
    //             return Order.eq;
    //         } else if (offset_a < offset_b) {
    //             return Order.lt;
    //         } else {
    //             return Order.gt;
    //         }
    //     }

    //     // If nodeA is following nodeB, then if the position of (nodeB, offsetB) relative to (nodeA, offsetA) is before, return after, and if it is after, return before.

    //     // If nodeA is an ancestor of nodeB:

    //     // Let child be nodeB.

    //     // While child is not a child of nodeA, set child to its parent.

    //     // If child’s index is less than offsetA, then return after.

    //     // Return before.

    // }
};
pub const Range = struct {
    start: BoundaryPoint,
    end: BoundaryPoint,

    pub const Direction = enum {
        forward,
        backward,
        none,
    };
    pub fn getCommonAncestorContainer(self: *Range, tree: *Tree) !Node.NodeId {
        return tree.getLowestCommonAncestorAndFirstDistinctAncestor(self.start.node_id, self.end.node_id).ancestor orelse error.NotInTheSameTree;
    }
    /// https://dom.spec.whatwg.org/#dom-range-setstart
    pub fn setStart(self: *Range, tree: *Tree, node_id: Node.NodeId, offset: u32) !void {
        // If offset is greater than node’s length, then throw an "IndexSizeError" DOMException.
        const node_length = tree.getNode(node_id).length;
        if (offset > node_length) {
            return error.OutOfBounds;
        }

        // Let bp be the boundary point (node, offset).
        const bp = BoundaryPoint{ .node_id = node_id, .offset = offset };
        // If range’s root is not equal to node’s root
        if (tree.getNodeRoot(node_id) != try self.getRoot(tree)) {
            self.end = bp;
        }
        // or if bp is after the range’s end, set range’s end to bp.
        if (try boundaryPointTreeOrder(tree, bp, self.end) == .gt) {
            self.end = bp;
        }
        // Set range’s start to bp.
        self.start = bp;
    }
    /// https://dom.spec.whatwg.org/#dom-range-setend
    pub fn setEnd(self: *Range, tree: *Tree, node_id: Node.NodeId, offset: u32) !void {
        // If offset is greater than node’s length, then throw an "IndexSizeError" DOMException.
        const node_length = tree.getNode(node_id).length;
        if (offset > node_length) {
            return error.OutOfBounds;
        }

        // Let bp be the boundary point (node, offset).
        const bp = BoundaryPoint{ .node_id = node_id, .offset = offset };
        // If range’s root is not equal to node’s root
        if (tree.getNodeRoot(node_id) != try self.getRoot(tree)) {
            self.start = bp;
        }
        // or if bp is before the range’s start, set range’s start to bp.
        if (try boundaryPointTreeOrder(tree, bp, self.start) == .lt) {
            self.start = bp;
        }
        // Set range’s end to bp.
        self.end = bp;
    }

    pub fn setStartBefore(self: *Range, tree: *Tree, node_id: Node.NodeId) !void {

        // Let parent be node’s parent.
        const parent = tree.getNode(node_id).parent orelse return error.InvalidNodeType;
        // If parent is null, then throw an "InvalidNodeTypeError" DOMException.

        // Set the start of this to boundary point (parent, node’s index).
        try self.setStart(tree, parent, tree.nodeIndex(node_id) orelse unreachable);
    }

    pub fn setStartAfter(self: *Range, tree: *Tree, node_id: Node.NodeId) !void {

        // Let parent be node’s parent.

        // If parent is null, then throw an "InvalidNodeTypeError" DOMException.
        const parent = tree.getNode(node_id).parent orelse return error.InvalidNodeType;

        // Set the start of this to boundary point (parent, node’s index plus 1).
        try self.setStart(tree, parent, (tree.nodeIndex(node_id) orelse unreachable) + 1);
    }

    pub fn setEndBefore(self: *Range, tree: *Tree, node_id: Node.NodeId) !void {
        // Let parent be node’s parent.
        const parent = tree.getNode(node_id).parent orelse return error.InvalidNodeType;

        // Set the end of this to boundary point (parent, node’s index).
        try self.setEnd(tree, parent, tree.nodeIndex(node_id) orelse unreachable);
    }

    pub fn setEndAfter(self: *Range, tree: *Tree, node_id: Node.NodeId) !void {
        // Let parent be node’s parent.
        const parent = tree.getNode(node_id).parent orelse return error.InvalidNodeType;

        // Set the end of this to boundary point (parent, node’s index plus 1).
        try self.setEnd(tree, parent, (tree.nodeIndex(node_id) orelse unreachable) + 1);
    }
    pub fn collapse(self: *Range, tree: *Tree, to_start: bool) !void {
        // The collapse(toStart) method steps are to, if toStart is true, set end to start; otherwise set start to end.

        if (to_start) {
            try self.setEnd(tree, self.start.node_id, self.start.offset);
        } else {
            try self.setStart(tree, self.end.node_id, self.end.offset);
        }
    }

    pub fn isCollapsed(self: Range) bool {
        return self.start.node_id == self.end.node_id and self.start.offset == self.end.offset;
    }
    /// The root of a live range is the root of its start node.
    pub fn getRoot(self: *Range, tree: *Tree) !Node.NodeId {
        return tree.getNodeRoot(self.start.node_id);
    }
    /// https://dom.spec.whatwg.org/#dom-range-selectnode
    pub fn selectNode(self: *Range, tree: *Tree, node_id: Node.NodeId) !void {

        // Let parent be node’s parent.

        // If parent is null, then throw an "InvalidNodeTypeError" DOMException.
        const parent = tree.getNode(node_id).parent orelse return error.InvalidNodeType;

        // Let index be node’s index.
        const index = tree.nodeIndex(node_id) orelse unreachable;
        // Set range’s start to boundary point (parent, index).
        try self.setStart(tree, parent, index);

        // Set range’s end to boundary point (parent, index plus 1).
        try self.setEnd(tree, parent, index + 1);
    }

    /// https://dom.spec.whatwg.org/#dom-range-selectnodecontents
    pub fn selectNodeContents(self: *Range, tree: *Tree, node_id: Node.NodeId) !void {
        // Let length be the length of node.
        const length = tree.getNode(node_id).length;
        // Set start to the boundary point (node, 0).
        try self.setStart(tree, node_id, 0);
        // Set end to the boundary point (node, length).
        try self.setEnd(tree, node_id, length);
    }
    pub const CompareBoundariesMode = enum {
        start_to_start,
        start_to_end,
        end_to_start,
        end_to_end,
    };
    /// The compareBoundaryPoints(how, sourceRange) method steps are:
    pub fn compareBoundaryPoints(self: Range, tree: *Tree, how: CompareBoundariesMode, source_range: Range) !Order {
        // If this’s root is not the same as sourceRange’s root, then throw a "WrongDocumentError" DOMException.
        const this_point, const other_point = switch (how) {
            // Let this point be this’s start. Let other point be sourceRange’s start.
            .start_to_start => .{ self.start, source_range.start },
            // Let this point be this’s end. Let other point be sourceRange’s start.
            .start_to_end => .{ self.end, source_range.start },
            // Let this point be this’s end. Let other point be sourceRange’s end.
            .end_to_end => .{ self.end, source_range.end },
            // Let this point be this’s start. Let other point be sourceRange’s end.
            .end_to_start => .{ self.start, source_range.end },
        };
        return boundaryPointTreeOrder(tree, this_point, other_point);
    }
    pub fn deleteContents(self: Range, tree: *Tree) !void {
        _ = tree; // autofix
        //  1.  If [this](https://webidl.spec.whatwg.org/#this) is [collapsed](#range-collapsed), then return.
        if (self.isCollapsed()) {
            return;
        }

        // 2.  Let original start node, original start offset, original end node, and original end offset be [this](https://webidl.spec.whatwg.org/#this)’s [start node](#concept-range-start-node), [start offset](#concept-range-start-offset), [end node](#concept-range-end-node), and [end offset](#concept-range-end-offset), respectively.
        const original_start_node = self.start.node_id;
        _ = original_start_node; // autofix
        const original_start_offset = self.start.offset;
        _ = original_start_offset; // autofix
        const original_end_node = self.end.node_id;
        _ = original_end_node; // autofix
        const original_end_offset = self.end.offset;
        _ = original_end_offset; // autofix
        // 3.  If original start node is original end node and it is a `[CharacterData](#characterdata)` [node](#concept-node), then [replace data](#concept-cd-replace) with node original start node, offset original start offset, count original end offset minus original start offset, and data the empty string, and then return.
        // if (original_start_node == original_end_node and tree.getNode(original_start_node).isCharacterData()) {
        //     try tree.replaceData(original_start_node, original_start_offset, original_end_offset - original_start_offset, "");
        //     return;
        // }
        // 4.  Let nodes to remove be a list of all the [nodes](#concept-node) that are [contained](#contained) in [this](https://webidl.spec.whatwg.org/#this), in [tree order](#concept-tree-order), omitting any [node](#concept-node) whose [parent](#concept-tree-parent) is also [contained](#contained) in [this](https://webidl.spec.whatwg.org/#this).
        // 5.  If original start node is an [inclusive ancestor](#concept-tree-inclusive-ancestor) of original end node, set new node to original start node and new offset to original start offset.
        // 6.  Otherwise:
        //     1.  Let reference node equal original start node.
        //     2.  While reference node’s [parent](#concept-tree-parent) is not null and is not an [inclusive ancestor](#concept-tree-inclusive-ancestor) of original end node, set reference node to its [parent](#concept-tree-parent).
        //     3.  Set new node to the [parent](#concept-tree-parent) of reference node, and new offset to one plus the [index](#concept-tree-index) of reference node.

        //         If reference node’s [parent](#concept-tree-parent) were null, it would be the [root](#concept-range-root) of [this](https://webidl.spec.whatwg.org/#this), so would be an [inclusive ancestor](#concept-tree-inclusive-ancestor) of original end node, and we could not reach this point.

        // 7.  If original start node is a `[CharacterData](#characterdata)` [node](#concept-node), then [replace data](#concept-cd-replace) with node original start node, offset original start offset, count original start node’s [length](#concept-node-length) − original start offset, data the empty string.

        // 8.  For each node in nodes to remove, in [tree order](#concept-tree-order), [remove](#concept-node-remove) node.

        // 9.  If original end node is a `[CharacterData](#characterdata)` [node](#concept-node), then [replace data](#concept-cd-replace) with node original end node, offset 0, count original end offset and data the empty string.

        // 10.  Set [start](#concept-range-start) and [end](#concept-range-end) to (new node, new offset).
        @panic("not implemented");
    }

    /// A node node is contained in a live range range if node’s root is range’s root, and (node, 0) is after range’s start, and (node, node’s length) is before range’s end.
    pub fn containsNode(self: Range, tree: *Tree, node_id: Node.NodeId) bool {
        if (tree.getNodeRoot(node_id) != self.getRoot(tree)) {
            return false;
        }
        const node_length = tree.getNodeLength(node_id);
        const start_order = try boundaryPointTreeOrder(tree, self.start, BoundaryPoint{ .node_id = node_id, .offset = 0 });
        const end_order = try boundaryPointTreeOrder(tree, self.end, BoundaryPoint{ .node_id = node_id, .offset = node_length });
        return start_order == .lt and end_order == .gt;
    }
    /// A node is partially contained in a live range if it’s an inclusive ancestor of the live range’s start node but not its end node, or vice versa.
    pub fn partiallyContainsNode(self: Range, tree: *Tree, node_id: Node.NodeId) !bool {
        // Check if the node's root is the range's root
        if (tree.getNodeRoot(node_id) != try self.getRoot(tree)) {
            return false;
        }

        // Check if node_id is an inclusive ancestor of start.node_id
        const is_inclusive_ancestor_of_start = (node_id == self.start.node_id) or tree.isNodeAncestor(node_id, self.start.node_id);

        // Check if node_id is an inclusive ancestor of end.node_id
        const is_inclusive_ancestor_of_end = (node_id == self.end.node_id) or tree.isNodeAncestor(node_id, self.end.node_id);

        // Node partially contains the range if it's an inclusive ancestor of one endpoint but not the other
        return (is_inclusive_ancestor_of_start and !is_inclusive_ancestor_of_end) or
            (!is_inclusive_ancestor_of_start and is_inclusive_ancestor_of_end);
    }
};
fn order(T: type, a: T, b: T) Order {
    if (a < b) {
        return .lt;
    } else if (a > b) {
        return .gt;
    }
    return .eq;
}
pub fn boundaryPointTreeOrder(tree: *Tree, boundary_point: BoundaryPoint, other: BoundaryPoint) !Order {
    // 1. Assert: same root
    if (tree.getNodeRoot(boundary_point.node_id) != tree.getNodeRoot(other.node_id)) {
        return error.NotInTheSameTree;
    }

    // 2. Same node case - compare offsets
    if (boundary_point.node_id == other.node_id) {
        if (boundary_point.offset < other.offset) return .lt;
        if (boundary_point.offset > other.offset) return .gt;
        return .eq;
    }

    // 3. If nodeA is following nodeB in tree order
    const node_order = try tree.treeOrder(boundary_point.node_id, other.node_id);
    if (node_order == .gt) { // nodeA follows nodeB
        // Do the recursive call, but implement it directly
        if (tree.isNodeAncestor(other.node_id, boundary_point.node_id)) {
            // Find child of other that leads to boundary_point
            var child = boundary_point.node_id;
            while (tree.getNode(child).parent.? != other.node_id) {
                child = tree.getNode(child).parent.?;
            }

            // Check position against offset
            const child_index = tree.nodeIndex(child) orelse unreachable;

            // If the recursive call would return .lt, we return .gt and vice versa
            if (child_index < other.offset) {
                return .gt; // Reversing .lt from the recursive call
            } else {
                return .lt; // Reversing .gt from the recursive call
            }
        } else {
            // Recursive call would reach step 5, returning .lt
            return .gt; // Reverse of .lt
        }
    }

    // 4. If nodeA is ancestor of nodeB
    if (tree.isNodeAncestor(boundary_point.node_id, other.node_id)) {
        // Find child of nodeA that leads to nodeB
        var child = other.node_id;
        while (tree.getNode(child).parent.? != boundary_point.node_id) {
            child = tree.getNode(child).parent.?;
        }

        // Compare child index to offsetA
        const child_index = tree.nodeIndex(child) orelse unreachable;
        if (child_index < boundary_point.offset) {
            return .gt; // "after" in spec terminology
        }
    }

    // 5. Default to "before"
    return .lt;
}
test "boundaryPointTreeOrder - comprehensive" {
    var tree = try Tree.init(std.testing.allocator);
    defer tree.deinit();

    // Create a more complex tree structure for thorough testing
    //                    root
    //                   /    \
    //              child_a    child_b
    //             /  |  \      /   \
    //    text_a_a text_a_b child_b_a text_b_b
    //                |
    //            text_a_b_a

    // Create the base structure
    const root = try tree.createNode();
    const child_a = try tree.createNode();
    const child_b = try tree.createNode();
    try tree.appendChild(root, child_a);
    try tree.appendChild(root, child_b);

    // Create text nodes and regular nodes
    const text_a_a = try tree.createTextNode("First text node");
    const text_a_b = try tree.createTextNode("Second text node with more content");
    const child_b_a = try tree.createNode();
    const text_b_b = try tree.createTextNode("Third text node");
    try tree.appendChild(child_a, text_a_a);
    try tree.appendChild(child_a, text_a_b);
    try tree.appendChild(child_a, child_b_a); // Reusing node_b_a under child_a
    try tree.appendChild(child_b, child_b_a);
    try tree.appendChild(child_b, text_b_b);

    const text_a_b_a = try tree.createTextNode("Deeply nested text");
    try tree.appendChild(text_a_b, text_a_b_a);

    // Create a separate tree for testing error cases
    const other_root = try tree.createNode();
    const other_child = try tree.createTextNode("Text in other tree");
    try tree.appendChild(other_root, other_child);

    // 1. Test same node, different offsets (step 2)
    {
        // Test same node, before
        var bp1 = BoundaryPoint{ .node_id = text_a_a, .offset = 2 };
        var bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = 5 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);

        // Test same node, after
        bp1 = BoundaryPoint{ .node_id = text_a_a, .offset = 8 };
        bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = 3 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .gt);

        // Test same node, equal
        bp1 = BoundaryPoint{ .node_id = text_a_a, .offset = 4 };
        bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = 4 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .eq);
    }

    // 2. Test one node following another in tree order (step 3)
    {
        // Case where nodeA follows nodeB in tree order, and nodeB is not an ancestor of nodeA
        var bp1 = BoundaryPoint{ .node_id = text_a_b, .offset = 0 };
        var bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = 0 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .gt);

        // Case where nodeA follows nodeB, and nodeB is an ancestor of nodeA
        bp1 = BoundaryPoint{ .node_id = text_a_b_a, .offset = 3 };
        bp2 = BoundaryPoint{ .node_id = text_a_b, .offset = 0 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .gt);

        // Case where nodeA follows nodeB, and nodeB is an ancestor of nodeA with offset greater than child index
        bp1 = BoundaryPoint{ .node_id = text_a_b_a, .offset = 5 };
        bp2 = BoundaryPoint{ .node_id = text_a_b, .offset = 1 }; // Assuming index of text_a_b_a is 0
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);
    }

    // 3. Test one node being an ancestor of another (step 4)
    {
        // nodeA is ancestor of nodeB and child index < offsetA
        var bp1 = BoundaryPoint{ .node_id = child_a, .offset = 2 };
        var bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = 3 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .gt);

        // nodeA is ancestor of nodeB and child index >= offsetA
        bp1 = BoundaryPoint{ .node_id = child_a, .offset = 0 };
        bp2 = BoundaryPoint{ .node_id = text_a_b, .offset = 4 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);

        // Root as ancestor
        bp1 = BoundaryPoint{ .node_id = root, .offset = 1 };
        bp2 = BoundaryPoint{ .node_id = child_b, .offset = 0 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);

        bp1 = BoundaryPoint{ .node_id = root, .offset = 2 };
        bp2 = BoundaryPoint{ .node_id = child_b, .offset = 0 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .gt);
    }

    // 4. Test nodes in different branches (step 5 - default case)
    {
        // nodes in different branches where neither is ancestor of the other
        const bp1 = BoundaryPoint{ .node_id = text_a_a, .offset = 5 };
        const bp2 = BoundaryPoint{ .node_id = text_b_b, .offset = 2 };

        // The result depends on tree order
        const expected = if ((try tree.treeOrder(text_a_a, text_b_b)) == .lt) .lt else .gt;
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), expected);
    }

    // 5. Test error case - nodes not in same tree
    {
        const bp1 = BoundaryPoint{ .node_id = root, .offset = 0 };
        const bp2 = BoundaryPoint{ .node_id = other_root, .offset = 0 };
        try std.testing.expectError(error.NotInTheSameTree, tree.boundaryPointTreeOrder(bp1, bp2));
    }

    // 6. Test complex scenario with deeply nested nodes
    {
        const bp1 = BoundaryPoint{ .node_id = root, .offset = 1 };
        const bp2 = BoundaryPoint{ .node_id = text_a_b_a, .offset = 5 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);

        bp1 = BoundaryPoint{ .node_id = text_a_b, .offset = 1 };
        bp2 = BoundaryPoint{ .node_id = text_a_b_a, .offset = 10 };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);
    }

    // 7. Test with text node offsets representing positions in the text
    {
        const text_content = tree.getText(text_a_a).items;
        const text_length = text_content.len;

        var bp1 = BoundaryPoint{ .node_id = text_a_a, .offset = 0 };
        var bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = @intCast(text_length) };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);

        bp1 = BoundaryPoint{ .node_id = child_a, .offset = 0 };
        bp2 = BoundaryPoint{ .node_id = text_a_a, .offset = @intCast(text_length / 2) };
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), .lt);
    }

    // 8. Test with rearranged tree to ensure algorithm adapts to structure changes
    try tree.removeChild(child_a, text_a_b);
    try tree.appendChild(child_b_a, text_a_b);

    {
        const bp1 = BoundaryPoint{ .node_id = child_a, .offset = 0 };
        const bp2 = BoundaryPoint{ .node_id = text_a_b, .offset = 0 };
        // The result should reflect the new tree structure
        const expected = if ((try tree.treeOrder(child_a, text_a_b)) == .lt) .lt else .gt;
        try std.testing.expectEqual(try tree.boundaryPointTreeOrder(bp1, bp2), expected);
    }
}
