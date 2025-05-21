const Tree = @import("./Tree.zig");
const Node = @import("./Node.zig");
const std = @import("std");

// This should get the first child of the node_id, not of its parent
pub fn firstChild(tree: *Tree, node_id: Node.NodeId) ?Node.NodeId {
    const children = tree.getChildren(node_id); // Changed from parent to node_id
    if (children.items.len == 0) {
        return null;
    }
    return children.items[0];
}

// Get the last child of a node
pub fn lastChild(tree: *Tree, node_id: Node.NodeId) ?Node.NodeId {
    const children = tree.getChildren(node_id);
    if (children.items.len == 0) {
        return null;
    }
    return children.items[children.items.len - 1];
}

pub fn nodeIndex(tree: *Tree, node_id: Node.NodeId) ?u32 {
    const parent = tree.getParent(node_id);
    if (parent == null) return null; // Handle root node case
    if (std.mem.indexOf(Node.NodeId, tree.getChildren(parent.?).items, &.{node_id})) |index| {
        return @intCast(index);
    }
    return null;
}

pub fn nextSibling(tree: *Tree, node_id: Node.NodeId) ?Node.NodeId {
    const parent = tree.getParent(node_id) orelse return null; // Handle root node
    const siblings = tree.getChildren(parent);
    const index = nodeIndex(tree, node_id) orelse return null;
    if (index == siblings.items.len - 1) {
        return null;
    }
    return siblings.items[index + 1];
}

pub fn previousSibling(tree: *Tree, node_id: Node.NodeId) ?Node.NodeId {
    const parent = tree.getParent(node_id) orelse return null; // Handle root node
    const siblings = tree.getChildren(parent);
    const index = nodeIndex(tree, node_id) orelse return null;
    if (index == 0) {
        return null;
    }
    return siblings.items[index - 1];
}

// Find the rightmost descendant (last child of last child...)
pub fn rightmostDescendant(tree: *Tree, node_id: Node.NodeId) Node.NodeId {
    var current = node_id;
    while (lastChild(tree, current)) |last| {
        current = last;
    }
    return current;
}

pub fn nextNode(tree: *Tree, node_id: Node.NodeId) ?Node.NodeId {
    if (firstChild(tree, node_id)) |child| {
        return child;
    }
    if (nextSibling(tree, node_id)) |sibling| {
        return sibling;
    }
    var ancestor = tree.getParent(node_id);
    while (ancestor) |parent| {
        if (nextSibling(tree, parent)) |sibling| {
            return sibling;
        }
        ancestor = tree.getParent(parent);
    }
    return null;
}

pub fn previousNode(tree: *Tree, node_id: Node.NodeId) ?Node.NodeId {
    // If has previous sibling, return its rightmost descendant
    if (previousSibling(tree, node_id)) |sibling| {
        return rightmostDescendant(tree, sibling);
    }

    // Otherwise, return the parent
    return tree.getParent(node_id);
}
