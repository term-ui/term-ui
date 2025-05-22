const Node = @import("./Node.zig");
const Tree = @import("./Tree.zig");
const traversal = @import("./traversal.zig");
const NodeIterator = @import("./NodeIterator.zig");
const std = @import("std");

pub const whatToShow = NodeIterator.whatToShow;
pub const FilterResult = NodeIterator.FilterResult;

const Self = @This();

pub const ChildType = enum { first, last };
pub const SiblingType = enum { next, previous };

tree: *Tree,
root: Node.NodeId,
current: Node.NodeId,
what_to_show: u32 = whatToShow.SHOW_ALL,

fn filterNode(self: *Self, node_id: Node.NodeId) FilterResult {
    const kind = self.tree.getNodeKind(node_id);
    switch (kind) {
        .node => {
            if ((self.what_to_show & whatToShow.SHOW_ELEMENT) != 0) {
                return .accept;
            }
            return .reject;
        },
        .text => {
            if ((self.what_to_show & whatToShow.SHOW_TEXT) != 0) {
                return .accept;
            }
            return .reject;
        },
    }
}

pub fn parentNode(self: *Self) ?Node.NodeId {
    var node = self.current;
    while (node != self.root) {
        node = self.tree.getParent(node) orelse return null;
        if (self.filterNode(node) == .accept) {
            self.current = node;
            return node;
        }
    }
    return null;
}

fn traverseChildren(self: *Self, comptime ty: ChildType) ?Node.NodeId {
    const start = self.current;
    var node = if (ty == .first)
        (traversal.firstChild(self.tree, start) orelse return null)
    else
        (traversal.lastChild(self.tree, start) orelse return null);

    while (true) {
        const result = self.filterNode(node);
        if (result == .accept) {
            self.current = node;
            return node;
        }
        if (result == .skip) {
            if (ty == .first) {
                if (traversal.firstChild(self.tree, node)) |child| {
                    node = child;
                    continue;
                }
            } else {
                if (traversal.lastChild(self.tree, node)) |child| {
                    node = child;
                    continue;
                }
            }
        }
        while (true) {
            const sibling = if (ty == .first)
                traversal.nextSibling(self.tree, node)
            else
                traversal.previousSibling(self.tree, node);
            if (sibling) |sib| {
                node = sib;
                break;
            }
            const parent = self.tree.getParent(node);
            if (parent == null or parent.? == self.root or parent.? == start) {
                return null;
            }
            node = parent.?;
        }
    }
    return null;
}

pub fn firstChild(self: *Self) ?Node.NodeId {
    return self.traverseChildren(.first);
}

pub fn lastChild(self: *Self) ?Node.NodeId {
    return self.traverseChildren(.last);
}

fn traverseSiblings(self: *Self, comptime ty: SiblingType) ?Node.NodeId {
    var node = self.current;
    if (node == self.root) return null;
    while (true) {
        var sibling = if (ty == .next)
            traversal.nextSibling(self.tree, node)
        else
            traversal.previousSibling(self.tree, node);
        while (sibling) |sib| {
            node = sib;
            const result = self.filterNode(node);
            if (result == .accept) {
                self.current = node;
                return node;
            }
            const child = if (ty == .next)
                traversal.firstChild(self.tree, node)
            else
                traversal.lastChild(self.tree, node);
            if (result == .reject or child == null) {
                sibling = if (ty == .next)
                    traversal.nextSibling(self.tree, node)
                else
                    traversal.previousSibling(self.tree, node);
            } else {
                sibling = child;
            }
        }
        node = self.tree.getParent(node) orelse return null;
        if (node == self.root) return null;
        if (self.filterNode(node) == .accept) return null;
    }
}

pub fn nextSibling(self: *Self) ?Node.NodeId {
    return self.traverseSiblings(.next);
}

pub fn previousSibling(self: *Self) ?Node.NodeId {
    return self.traverseSiblings(.previous);
}

pub fn previousNode(self: *Self) ?Node.NodeId {
    var node = self.current;
    while (node != self.root) {
        var sibling = traversal.previousSibling(self.tree, node);
        while (sibling) |sib| {
            node = sib;
            var result = self.filterNode(node);
            while (result != .reject) {
                if (traversal.lastChild(self.tree, node)) |child| {
                    node = child;
                    result = self.filterNode(node);
                } else break;
            }
            if (result == .accept) {
                self.current = node;
                return node;
            }
            sibling = traversal.previousSibling(self.tree, node);
        }
        if (node == self.root or self.tree.getParent(node) == null) return null;
        node = self.tree.getParent(node).?;
        if (self.filterNode(node) == .accept) {
            self.current = node;
            return node;
        }
    }
    return null;
}

pub fn nextNode(self: *Self) ?Node.NodeId {
    var node = self.current;
    var result: FilterResult = .accept;
    while (true) {
        while (result != .reject) {
            if (traversal.firstChild(self.tree, node)) |child| {
                node = child;
                result = self.filterNode(node);
                if (result == .accept) {
                    self.current = node;
                    return node;
                }
                continue;
            }
            break;
        }
        var sibling: ?Node.NodeId = null;
        var temporary = node;
        while (temporary != null) {
            if (temporary == self.root) return null;
            sibling = traversal.nextSibling(self.tree, temporary);
            if (sibling) |sib| {
                node = sib;
                break;
            }
            temporary = self.tree.getParent(temporary) orelse return null;
        }
        result = self.filterNode(node);
        if (result == .accept) {
            self.current = node;
            return node;
        }
    }
}

pub fn currentNode(self: *Self) Node.NodeId {
    return self.current;
}

pub fn setCurrentNode(self: *Self, node_id: Node.NodeId) void {
    self.current = node_id;
}

 test "TreeWalker next/previous node" {
     const allocator = std.testing.allocator;
     var tree = try Tree.parseTree(allocator,
         \\<view>
         \\  <view>
         \\    <view>
         \\      <view></view>
         \\    </view>
         \\    <view>
         \\      <view></view>
         \\    </view>
         \\  </view>
         \\  <view>
         \\    <view><text>Hello</text></view>
         \\    <view></view>
         \\  </view>
         \\</view>
     );
     defer tree.deinit();

     var walker = tree.createTreeWalker(0);
     var expected: Node.NodeId = 1;
     while (walker.nextNode()) |node_id| {
         try std.testing.expectEqual(expected, node_id);
         expected += 1;
     }
     try std.testing.expectEqual(tree.node_map.count(), expected);

     walker.setCurrentNode(tree.node_map.count() - 1);
     var i: Node.NodeId = tree.node_map.count();
     while (walker.previousNode()) |node_id| {
         i -= 1;
         try std.testing.expectEqual(i, node_id);
     }
     try std.testing.expectEqual(@as(Node.NodeId, 0), i);
 }

 test "TreeWalker basic navigation" {
     const allocator = std.testing.allocator;
     var tree = try Tree.parseTree(allocator,
         \\<view>
         \\  <view>
         \\    <view>
         \\      <view></view>
         \\    </view>
         \\    <view>
         \\      <view></view>
         \\    </view>
         \\  </view>
         \\  <view>
         \\    <view><text>Hello</text></view>
         \\    <view></view>
         \\  </view>
         \\</view>
     );
     defer tree.deinit();

     var walker = tree.createTreeWalker(0);
     try std.testing.expectEqual(@as(?Node.NodeId, 1), walker.firstChild());
     try std.testing.expectEqual(@as(Node.NodeId, 1), walker.currentNode());

     try std.testing.expectEqual(@as(?Node.NodeId, 6), walker.nextSibling());
     try std.testing.expectEqual(@as(Node.NodeId, 6), walker.currentNode());

     try std.testing.expectEqual(@as(?Node.NodeId, 0), walker.parentNode());
     try std.testing.expectEqual(@as(Node.NodeId, 0), walker.currentNode());

     try std.testing.expectEqual(@as(?Node.NodeId, 6), walker.lastChild());
     try std.testing.expectEqual(@as(Node.NodeId, 6), walker.currentNode());

     try std.testing.expectEqual(@as(?Node.NodeId, 1), walker.previousSibling());
     try std.testing.expectEqual(@as(Node.NodeId, 1), walker.currentNode());
 }
