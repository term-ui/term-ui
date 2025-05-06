pub const Node = @import("Node.zig");
const Point = @import("../point.zig").Point;
const std = @import("std");
const xml = @import("../../xml.zig");
pub const Style = @import("Style.zig");
const Color = @import("../../colors/Color.zig");
const compute_root_layout = @import("../compute/compute_root_layout.zig").compute_root_layout;
const round_layout = @import("../compute/round_layout.zig").round_layout;
const HashMap = std.AutoHashMap;
const Layout = @import("Layout.zig");
const Cache = @import("Cache.zig");
const ComputedText = @import("../compute/text/ComputedText.zig");
const Rect = @import("../rect.zig").Rect;
pub const AvailableSpace = @import("../compute/compute_constants.zig").AvailableSpace;
const s = @import("../../styles/styles.zig");
const ComputedStyleCache = s.computed_style.ComputedStyleCache;
const StyleManager = s.style_manager.StyleManager;
const InputManager = @import("../../cmd/input/manager.zig").AnyInputManager;
const Event = @import("../../cmd/input/manager.zig").Event;
const Selection = @import("Selection.zig");

node_map: std.AutoHashMapUnmanaged(Node.NodeId, Node) = .{},
allocator: std.mem.Allocator,
style_manager: StyleManager,
computed_style_cache: ComputedStyleCache,
input_manager: ?InputManager = null,

node_id_counter: Node.NodeId = 0,

const Self = @This();

pub const ROOT_NODE_ID: Node.NodeId = 0;
pub fn init(allocator: std.mem.Allocator) !Self {
    // Initialize style system and tree together
    return Self{
        .allocator = allocator,
        .style_manager = try StyleManager.init(allocator),
        .computed_style_cache = try ComputedStyleCache.init(allocator),
        // .selection = .{
        //     .allocator = allocator,
        // },
    };
}

pub fn enableInputManager(self: *Self) !void {
    self.input_manager = .{
        .allocator = self.allocator,
    };
    try self.input_manager.?.subscribe(.{
        .context = @ptrCast(self),
        .emitFn = emitEventFn,
    });
}
pub fn disableInputManager(self: *Self) void {
    if (self.input_manager) |*manager| {
        manager.unsubscribe(@ptrCast(self));
    }
}
fn emitEventFn(context: *anyopaque, event: Event) void {
    _ = event; // autofix
    _ = context; // autofix
}
pub inline fn getNode(self: *Self, id: Node.NodeId) *Node {
    return self.node_map.getPtr(id).?;
}
pub fn getNodeKind(self: *Self, id: Node.NodeId) Node.NodeKind {
    return self.getNode(id).kind;
}
pub inline fn getChildren(self: *Self, id: Node.NodeId) std.ArrayListUnmanaged(Node.NodeId) {
    return self.getNode(id).children;
}
pub inline fn isEmpty(self: *Self, id: Node.NodeId) bool {
    if (self.getNodeKind(id) == .text) {
        return self.getText(id).items.len == 0;
    }
    return self.getChildren(id).items.len == 0;
}
pub inline fn getStyle(self: *Self, id: Node.NodeId) *Style {
    return &self.getNode(id).styles;
}
pub inline fn getText(self: *Self, id: Node.NodeId) std.ArrayListUnmanaged(u8) {
    return self.getNode(id).text;
}
pub inline fn getParent(self: *Self, id: Node.NodeId) ?Node.NodeId {
    return self.getNode(id).parent;
}
pub inline fn getUnroundedLayout(self: *Self, id: Node.NodeId) *Layout {
    return &self.getNode(id).unrounded_layout;
}
pub inline fn getLayout(self: *Self, id: Node.NodeId) *Layout {
    return &self.getNode(id).layout;
}
pub inline fn getCache(self: *Self, id: Node.NodeId) *Cache {
    return &self.getNode(id).cache;
}
pub inline fn getComputedText(self: *Self, id: Node.NodeId) *?ComputedText {
    return &self.getNode(id).computed_text;
}
pub inline fn getTextRootId(self: *Self, id: Node.NodeId) ?Node.NodeId {
    return self.getNode(id).text_root_id;
}
pub inline fn setTextRootId(self: *Self, id: Node.NodeId, text_root_id: ?Node.NodeId) void {
    self.getNode(id).text_root_id = text_root_id;
}

// node setters
pub fn setNodeKind(self: *Self, id: Node.NodeId, kind: Node.NodeKind) !void {
    self.getNode(id).kind = kind;
}
pub fn setChildren(self: *Self, id: Node.NodeId, children: []Node.NodeId) !void {
    const list = self.getNode(id).children;
    list.clearAndFree();
    try list.appendSlice(self.allocator, children);
}
pub fn setStyle(self: *Self, id: Node.NodeId, style: Style) void {
    self.getNode(id).styles.deinit();
    self.getNode(id).styles = style;

    // Mark node dirty for layout
    self.markDirty(id);

    // Invalidate computed styles for this node and descendants
    self.invalidateStyles(id);
}
pub fn setText(self: *Self, id: Node.NodeId, text: []const u8) !void {
    var node = self.getNode(id);
    if (std.mem.eql(u8, node.text.items, text)) {
        return;
    }
    node.text.clearRetainingCapacity();
    try node.text.appendSlice(self.allocator, text);
    self.markDirty(id);
}

pub fn setParent(self: *Self, id: Node.NodeId, parent: ?Node.NodeId) void {
    var node = self.getNode(id);
    if (node.parent == parent) {
        return;
    }

    if (node.parent) |current_parent_id| {
        self.removeChild(current_parent_id, id);
    }
    node.parent = parent;
}
pub fn setUnroundedLayout(self: *Self, id: Node.NodeId, unrounded_layout: Layout) void {
    self.getNode(id).unrounded_layout = unrounded_layout;
}
pub fn setLayout(self: *Self, id: Node.NodeId, layout: Layout) void {
    self.getNode(id).layout = layout;
}
pub fn setCache(self: *Self, id: Node.NodeId, cache: Cache) void {
    self.getNode(id).cache = cache;
}
pub fn setComputedText(self: *Self, id: Node.NodeId, computed_text: ComputedText) void {
    if (self.getNode(id).computed_text) |*old_computed_text| {
        old_computed_text.deinit();
    }
    self.getNode(id).computed_text = computed_text;
}

pub inline fn createComputedText(self: *Self) !ComputedText {
    // const computed_text_list = self.getComputedTextList();
    // computed_text_list[node_id] = try ComputedText.init(self.allocator);
    return try ComputedText.init(self.allocator);
}
// fn isDirectChildOf(self: *Self, node_id: Node.NodeId, parent_id: Node.NodeId) bool {
//     const children = self.getChildren(parent_id);
//     for (children.items) |child| {
//         if (child == node_id) {
//             return true;
//         }
//     }
//     return false;

// }

pub fn markDirty(self: *Self, id: Node.NodeId) void {
    const cache = self.getCache(id);
    const computed_text = self.getComputedText(id);
    const text_root_id = self.getTextRootId(id);
    if (cache.isEmpty() and text_root_id == null) {
        return;
    }

    // Clear layout cache
    cache.clear();
    self.setTextRootId(id, null);
    if (computed_text.* != null) {
        computed_text.*.?.deinit();
        computed_text.* = null;
    }

    // Also invalidate computed style for this specific node
    // We only invalidate this node, not descendants, since layout changes
    // don't necessarily affect cascaded styles of children
    self.computed_style_cache.invalidateNode(id);

    // Propagate to parent
    if (self.getParent(id)) |parent_id| {
        self.markDirty(parent_id);
    }
}

pub fn destroyNode(self: *Self, id: Node.NodeId) void {
    const node = self.getNode(id);
    for (node.children.items) |child_id| {
        var child = self.getNode(child_id);
        child.parent = null;
    }
    self.setParent(id, null);

    node.deinit(self.allocator);
    _ = self.node_map.remove(id);
}
pub fn destroyNodeRecursive(self: *Self, id: Node.NodeId) void {
    self.setParent(id, null);
    self.destroyNodeRecursiveInner(id);
}
fn destroyNodeRecursiveInner(self: *Self, id: Node.NodeId) void {
    const node = self.getNode(id);
    for (node.children.items) |child_id| {
        self.destroyNodeRecursiveInner(child_id);
    }
    node.deinit(self.allocator);
    _ = self.node_map.remove(id);
}
// node creation
pub fn createNode(self: *Self) !Node.NodeId {
    const id = self.node_id_counter;
    self.node_id_counter += 1;

    try self.node_map.put(self.allocator, id, .{
        .id = id,
        .styles = .{},
    });

    return id;
}

pub fn createTextNode(self: *Self, text: []const u8) !Node.NodeId {
    const id = self.node_id_counter;
    self.node_id_counter += 1;
    try self.node_map.put(self.allocator, id, .{
        .id = id,
        .kind = .text,
        .styles = .{
            .display = .{ .inside = .flow, .outside = .@"inline" },
        },
    });
    try self.setText(id, text);

    return id;
}
pub fn appendChildAtIndex(self: *Self, parent_id: Node.NodeId, child_id: Node.NodeId, index: usize) !void {
    self.setParent(child_id, parent_id);
    var parent = self.getNode(parent_id);

    if (index >= parent.children.items.len) {
        try parent.children.append(self.allocator, child_id);
    } else {
        try parent.children.insert(self.allocator, index, child_id);
    }
    self.markDirty(parent_id);
}

pub fn appendChild(self: *Self, parent_id: Node.NodeId, child_id: Node.NodeId) !void {
    self.setParent(child_id, parent_id);
    var parent = self.getNode(parent_id);
    try parent.children.append(self.allocator, child_id);
    self.markDirty(parent_id);
}
pub fn insertBefore(self: *Self, parent_id: Node.NodeId, child_id: Node.NodeId, before_id: Node.NodeId) !void {
    self.setParent(child_id, parent_id);
    // var child = self.getNode(child_id);
    var parent = self.getNode(parent_id);
    const index = std.mem.indexOfScalar(Node.NodeId, parent.children.items, before_id);
    if (index) |i| {
        try parent.children.insert(self.allocator, i, child_id);
    } else {
        try parent.children.append(self.allocator, child_id);
    }
    self.markDirty(parent_id);
}

pub fn removeChild(self: *Self, parent_id: Node.NodeId, child_id: Node.NodeId) void {
    var parent = self.getNode(parent_id);
    const index = std.mem.indexOfScalar(Node.NodeId, parent.children.items, child_id);
    if (index) |i| {
        _ = parent.children.orderedRemove(i);
    } else {
        return;
    }
    // dont call setParent to avoid infinite loop
    self.getNode(child_id).parent = null;
    self.markDirty(parent_id);
}
pub fn removeChildren(self: *Self, parent_id: Node.NodeId) void {
    var node = self.getNode(parent_id);
    if (node.children.items.len == 0) {
        return;
    }
    for (node.children.items) |child_id| {
        self.getNode(child_id).parent = null;
    }
    node.children.clearRetainingCapacity();
    self.markDirty(parent_id);
}

pub fn getNodeContains(self: *Self, parent_id: Node.NodeId, maybe_child_id: Node.NodeId) bool {
    var parent = self.getNode(maybe_child_id).parent;
    while (parent) |p| {
        if (p == parent_id) {
            return true;
        }
        parent = self.getNode(p).parent;
    }
    return false;
}
pub fn deinit(self: *Self) void {
    var node_iter = self.node_map.iterator();
    if (self.input_manager) |*manager| {
        manager.deinit();
    }
    // std.debug.print("deinit {d} nodes\n", .{self.node_map.count()});
    while (node_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.node_map.deinit(self.allocator);

    // Clean up style system
    self.style_manager.deinit();
    self.computed_style_cache.deinit();
}
pub fn getNodeCount(self: *Self) usize {
    return self.node_map.count();
}
fn printNode(self: *Self, writer: std.io.AnyWriter, node_id: Node.NodeId, indent: usize) !void {
    // const node = self.getNode(node_id);
    try writer.writeByteNTimes(' ', indent * 4);
    const layout = self.getLayout(node_id);
    const kind = self.getNodeKind(node_id);
    if (kind == .text) {
        try writer.print("[{s} #{d}] \"{s}\"\n", .{ @tagName(kind), node_id, self.getText(node_id).items });
    } else {
        const display = self.getStyle(node_id).display;
        const has_computed_text = self.getComputedText(node_id).* != null;

        try writer.print("[{s}#{d} {s} {s} {any} #{d} pos=[{d},{d}] size=[{d},{d}] content_size=[{d},{d}] border=[{d}, {d}, {d}, {d}]]\n", .{
            @tagName(kind),
            node_id,
            @tagName(display.outside),
            @tagName(display.inside),
            has_computed_text,
            node_id,
            layout.location.x,
            layout.location.y,
            layout.size.x,
            layout.size.y,
            layout.content_size.x,
            layout.content_size.y,
            layout.border.top,
            layout.border.right,
            layout.border.bottom,
            layout.border.left,
        });
        // } else {
        //     try writer.print("[{s} {s} {s}  #{d} x={d} y={d} width={d} height={d}]\n", .{
        //         @tagName(kind),
        //         @tagName(display.outside),
        //         @tagName(display.inside),
        //         node_id,
        //         layout.location.x,
        //         layout.location.y,
        //         layout.size.x,
        //         layout.size.y,
        //     });
        // }
    }

    for (self.getChildren(node_id).items) |child_id| {
        try self.printNode(writer, child_id, indent + 1);
    }
}
pub fn print(self: *Self, writer: std.io.AnyWriter) !void {
    try self.printNode(writer, 0, 0);
}

pub inline fn parseTree(allocator: std.mem.Allocator, tree_string: []const u8) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const doc = try xml.parse(a, tree_string);
    var tree = try init(allocator);
    errdefer tree.deinit();
    _ = try fromXmlElement(&tree, doc.root);

    return tree;
}
fn fromXmlElement(tree: *Self, node: *xml.Element) !Node.NodeId {
    const is_text_node = std.mem.eql(u8, node.tag, "text");

    // var style = Style.init(tree.allocator);
    // errdefer style.deinit();
    const node_id = try tree.createNode();
    var style = &tree.getNode(node_id).styles;
    if (is_text_node) {
        style.display = .{ .inside = .flow, .outside = .@"inline" };
    }

    for (node.attributes) |attr| {
        if (std.mem.eql(u8, attr.name, "style")) {
            try s.parseStyleString(tree, node_id, attr.value);
            continue;
        }
        if (std.mem.eql(u8, attr.name, "scroll-y")) {
            tree.getNode(node_id).scroll_offset.y = std.fmt.parseFloat(f32, attr.value) catch unreachable;
            continue;
        }
        if (std.mem.eql(u8, attr.name, "scroll-x")) {
            tree.getNode(node_id).scroll_offset.x = std.fmt.parseFloat(f32, attr.value) catch unreachable;
            continue;
        }
    }
    for (node.children) |child| {
        switch (child) {
            .element => |el| {
                const child_id = try fromXmlElement(tree, el);
                try tree.appendChild(node_id, child_id);
            },
            .char_data => |text| {
                if (!is_text_node) continue;
                const child_id = try tree.createTextNode(text);
                try tree.appendChild(node_id, child_id);
            },
            else => {},
        }
    }
    return node_id;
}

/// Get the computed style for a node, accounting for inheritance and cascading
pub fn getComputedStyle(self: *Self, node_id: Node.NodeId) Style {
    return self.computed_style_cache.getComputedStyle(self, node_id);
}

/// Invalidate computed styles for a node and its descendants
pub fn invalidateStyles(self: *Self, node_id: Node.NodeId) void {
    // Invalidate all computed styles for this node and its descendants
    self.computed_style_cache.invalidateTree(self, node_id);

    // Mark the node as dirty to trigger layout recalculation
    self.markDirty(node_id);
}

pub fn computeLayout(self: *Self, allocator: std.mem.Allocator, available_space: Point(AvailableSpace)) !void {
    // Compute the actual layout

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var root_style: Style = .{};
    root_style.text_decoration = .{
        .line = .none,
    };
    root_style.font_weight = .normal;
    root_style.font_style = .normal;
    root_style.text_align = .left;
    root_style.text_wrap = .wrap;

    try self.computed_style_cache.computeStyle(self, 0, root_style);

    try compute_root_layout(arena.allocator(), self, available_space);
    round_layout(0, self, 0);
}

test "createtree" {
    var tree = try parseTree(std.testing.allocator,
        \\<div display="flex" width="20"  flex-direction="column" justify-content="center" overflow="hidden">
        // \\  <div display="block" width="100%" height="100%">
        \\    <span><div display="block" width="1" height="1"></div>Lorem ipsum dolor sit am <div display="inline-block"></div>et<div display="block" width="1" height="1"></div></span>
        // \\    <span>Lorem ipsum dolor sit am<span>et, cons</span>ec<span>tetur adipiscing elit. </span></span>
        // \\    <span>Lorem ipsum dolor sit am<span>et, cons</span>ec<span>tetur adipiscing elit. </span></span>
        // \\  </div>
        \\</div>
    );
    defer tree.deinit();
    // const root = tree.getNode(0);
    const writer = std.io.getStdErr().writer().any();
    try tree.print(writer);

    const testing_allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(testing_allocator);
    defer arena.deinit();
    try compute_root_layout(arena.allocator(), &tree, .{ .x = .{ .definite = 100 }, .y = .{ .definite = 100 } });

    round_layout(0, &tree, 1);
    const layout = tree.getLayout(0);
    std.debug.print("\n\nlayout:\n{any}\n", .{(layout)});
    try tree.print(writer);
}

pub fn getNodeChildren(self: *Self, node_id: Node.NodeId) []const Node.NodeId {
    switch (self.getNode(node_id).kind) {
        .text => return &[_]Node.NodeId{},
        .node => return self.getNode(node_id).children.items,
    }
}

/// https://dom.spec.whatwg.org/#concept-tree-root
/// The root of an object is itself, if its parent is null, or else it is the root of its parent. The root of a tree is any object participating in that tree whose parent is null.
pub fn getNodeRoot(self: *Self, node_id: Node.NodeId) Node.NodeId {
    var current: Node.NodeId = node_id;
    while (self.getNode(current).parent) |parent| {
        current = parent;
    }
    return current;
}

/// https://dom.spec.whatwg.org/#trees
/// An object A is called a descendant of an object B, if either A is a child of B or A is a child of an object C that is a descendant of B.
pub fn isNodeDescendant(self: *Self, node_id: Node.NodeId, maybe_ancestor_id: Node.NodeId) bool {
    if (maybe_ancestor_id == node_id) return false;
    var current: Node.NodeId = node_id;
    while (self.getNode(current).parent) |parent| {
        if (parent == maybe_ancestor_id) return true;
        current = parent;
    }
    return false;
}

pub fn isNodeAncestor(self: *Self, node_id: Node.NodeId, maybe_descendant_id: Node.NodeId) bool {
    return self.isNodeDescendant(maybe_descendant_id, node_id);
}
pub fn getLowestCommonAncestorAndFirstDistinctAncestor(self: *Self, a: Node.NodeId, b: Node.NodeId) struct {
    ancestor: ?Node.NodeId,
    distinct_a_child: ?Node.NodeId,
    distinct_b_child: ?Node.NodeId,
} {
    // Same node check
    if (a == b)
        return .{ .ancestor = a, .distinct_a_child = null, .distinct_b_child = null };

    // Find depths
    var depth_a: usize = 0;
    var depth_b: usize = 0;
    var current = a;
    while (self.getNode(current).parent) |parent| {
        depth_a += 1;
        current = parent;
    }
    current = b;
    while (self.getNode(current).parent) |parent| {
        depth_b += 1;
        current = parent;
    }

    // Set x to deeper node, y to shallower node
    var x, var y, const difference = if (depth_a >= depth_b) .{ a, b, depth_a - depth_b } else .{ b, a, depth_b - depth_a };

    // Track child on deeper node's path
    var distinctAncestorA: ?Node.NodeId = null;

    // Move up from deeper node to equalize depths
    for (0..difference) |_| {
        distinctAncestorA = x;
        x = self.getNode(x).parent orelse return .{ .ancestor = null, .distinct_a_child = null, .distinct_b_child = null };
    }

    // Track child on shallower node's path
    var distinctAncestorB: ?Node.NodeId = null;

    // Find LCA by moving up both nodes
    while (x != y) {
        distinctAncestorA = x;
        distinctAncestorB = y;
        x = self.getNode(x).parent orelse return .{ .ancestor = null, .distinct_a_child = null, .distinct_b_child = null };
        y = self.getNode(y).parent orelse return .{ .ancestor = null, .distinct_a_child = null, .distinct_b_child = null };
    }

    // Swap back to ensure children match original a and b
    if (depth_a < depth_b) {
        std.mem.swap(?Node.NodeId, &distinctAncestorA, &distinctAncestorB);
    }

    return .{ .ancestor = x, .distinct_a_child = distinctAncestorA, .distinct_b_child = distinctAncestorB };
}

/// An object A is called a sibling of an object B, if and only if B and A share the same non-null parent.
pub fn isNodeSibling(self: *Self, node_id: Node.NodeId, maybe_sibling_id: Node.NodeId) bool {
    if (node_id == maybe_sibling_id) return false;
    const node_parent = self.getNode(node_id).parent;
    if (node_parent == null) return false;

    return self.getNode(maybe_sibling_id).parent == node_parent;
}

pub fn firstChild(self: *Self, node_id: Node.NodeId) ?Node.NodeId {
    const node = self.getNode(node_id);
    if (node.children.items.len == 0) return null;
    return node.children.items[0];
}

pub fn lastChild(self: *Self, node_id: Node.NodeId) ?Node.NodeId {
    const node = self.getNode(node_id);
    if (node.children.items.len == 0) return null;
    return node.children.items[node.children.items.len - 1];
}

pub fn nodeIndex(self: *Self, node_id: Node.NodeId) ?usize {
    const node = self.getNode(node_id);
    const parent = node.parent orelse return null;
    const siblings = self.getNodeChildren(parent);
    return std.mem.indexOfScalar(Node.NodeId, siblings, node_id);
}

pub fn nextSibling(self: *Self, node_id: Node.NodeId) ?Node.NodeId {
    const node = self.getNode(node_id);
    const parent = node.parent orelse return null;
    const siblings = self.getNodeChildren(parent);

    const index = std.mem.indexOfScalar(Node.NodeId, siblings, node_id) orelse return null;
    if (index == siblings.len - 1) return null;
    return siblings[index + 1];
}
pub fn previousSibling(self: *Self, node_id: Node.NodeId) ?Node.NodeId {
    const node = self.getNode(node_id);
    const parent = node.parent orelse return null;
    const siblings = self.getNodeChildren(parent);

    const index = self.nodeIndex(node_id) orelse return null;
    if (index == 0) return null;
    return siblings[index - 1];
}
pub fn isSubsequentSibling(self: *Self, node_a: Node.NodeId, node_b: Node.NodeId) bool {
    if (node_a == node_b) return false;
    const a_parent = self.getNode(node_a).parent orelse return false;
    const b_parent = self.getNode(node_b).parent orelse return false;
    if (a_parent != b_parent) return false;
    const siblings = self.getNodeChildren(a_parent);
    const a_index = std.mem.indexOfScalar(Node.NodeId, siblings, node_a) orelse unreachable;
    if (a_index == siblings.len - 1) return false;
    for (siblings[a_index + 1 ..]) |child| {
        if (child == node_b) return true;
    }
    return false;
}
const Order = std.math.Order;
/// In tree order is preorder, depth-first traversal of a tree.
pub fn treeOrder(self: *Self, node_a: Node.NodeId, node_b: Node.NodeId) !Order {
    if (node_a == node_b) return .eq;
    const lca = self.getLowestCommonAncestorAndFirstDistinctAncestor(node_a, node_b);
    if (lca.ancestor == null) return error.NotInTheSameTree;
    const distinct_a_child = lca.distinct_a_child orelse return .lt;
    const distinct_b_child = lca.distinct_b_child orelse return .gt;
    if (self.isSubsequentSibling(distinct_a_child, distinct_b_child)) return .lt;
    return .gt;
}

test "treeOrder - comprehensive" {
    var tree = try init(std.testing.allocator);
    defer tree.deinit();

    // Create a more complex tree structure
    //                    root
    //                   /    \
    //                child_a  child_b
    //               /  |  \    /   \
    //     child_a_a child_a_b child_b_a child_b_b
    //                 |
    //             child_a_b_a

    const root = try tree.createNode();
    const child_a = try tree.createNode();
    const child_b = try tree.createNode();
    try tree.appendChild(root, child_a);
    try tree.appendChild(root, child_b);

    const child_a_a = try tree.createNode();
    const child_a_b = try tree.createNode();
    const child_a_c = try tree.createNode();
    try tree.appendChild(child_a, child_a_a);
    try tree.appendChild(child_a, child_a_b);
    try tree.appendChild(child_a, child_a_c);

    const child_b_a = try tree.createNode();
    const child_b_b = try tree.createNode();
    try tree.appendChild(child_b, child_b_a);
    try tree.appendChild(child_b, child_b_b);

    const child_a_b_a = try tree.createNode();
    try tree.appendChild(child_a_b, child_a_b_a);

    // Let's add some deeper nodes for more complex testing
    const child_b_b_a = try tree.createNode();
    try tree.appendChild(child_b_b, child_b_b_a);

    const child_a_c_a = try tree.createNode();
    const child_a_c_b = try tree.createNode();
    try tree.appendChild(child_a_c, child_a_c_a);
    try tree.appendChild(child_a_c, child_a_c_b);

    // 1. Self comparison
    try std.testing.expectEqual(try tree.treeOrder(root, root), .eq);
    try std.testing.expectEqual(try tree.treeOrder(child_a, child_a), .eq);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_a_b_a), .eq);

    // 2. Basic sibling order tests
    try std.testing.expectEqual(try tree.treeOrder(child_a, child_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b, child_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_a, child_a_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b, child_a_c), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c, child_a_a), .gt);

    // 3. Parent-child relationships
    try std.testing.expectEqual(try tree.treeOrder(root, child_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a, root), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a, child_a_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b, child_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b, child_a_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_a_b), .gt);

    // 4. Cross-branch comparisons
    try std.testing.expectEqual(try tree.treeOrder(child_a_a, child_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b_a, child_a_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c, child_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b_a, child_a_c), .gt);

    // 5. Deep cross-branch comparisons
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_b_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b_b_a, child_a_b_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c_a, child_b_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b_b_a, child_a_c_b), .gt);

    // 6. Uncle/aunt to niece/nephew comparisons
    try std.testing.expectEqual(try tree.treeOrder(child_a, child_b_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b_b_a, child_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c, child_a_b_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_a_c), .lt);

    // 7. Nodes at different depths
    try std.testing.expectEqual(try tree.treeOrder(child_a_a, child_a_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_a_c), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_a_c_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b_a, child_b_b_a), .lt);

    // 8. Root comparisons
    try std.testing.expectEqual(try tree.treeOrder(root, child_a_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(root, child_b_b_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c_b, root), .gt);

    // 9. Test complex ancestor relationships
    try std.testing.expectEqual(try tree.treeOrder(child_a_c_a, child_a_c_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c_b, child_a_c_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_a_c_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_c_a, child_a_b_a), .gt);

    // 10. Test modified tree structure
    // Let's move a subtree and test the new relationships
    tree.removeChild(child_a, child_a_b);
    try tree.appendChild(child_b_a, child_a_b);

    // Now child_a_b is under child_b_a
    try std.testing.expectEqual(try tree.treeOrder(child_b_a, child_a_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b, child_b_a), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_a, child_a_b), .lt); // different branches now
    try std.testing.expectEqual(try tree.treeOrder(child_a_b, child_b_b), .lt); // now child_a_b comes before child_b_b
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, child_b_b), .lt); // child_a_b_a follows its parent

    // 11. Test disconnected nodes
    const disconnected1 = try tree.createNode();
    const disconnected2 = try tree.createNode();

    // Create a separate tree
    const other_root = try tree.createNode();
    const other_child = try tree.createNode();
    try tree.appendChild(other_root, other_child);

    // Test that comparing disconnected nodes returns an error
    try std.testing.expectError(error.NotInTheSameTree, tree.treeOrder(disconnected1, disconnected2));
    try std.testing.expectError(error.NotInTheSameTree, tree.treeOrder(root, disconnected1));
    try std.testing.expectError(error.NotInTheSameTree, tree.treeOrder(disconnected1, root));

    // Test that comparing nodes in separate trees returns an error
    try std.testing.expectError(error.NotInTheSameTree, tree.treeOrder(root, other_root));
    try std.testing.expectError(error.NotInTheSameTree, tree.treeOrder(other_child, child_a));
    try std.testing.expectError(error.NotInTheSameTree, tree.treeOrder(child_b_b_a, other_child));

    // 12. Test edge cases with root and direct children
    try std.testing.expectEqual(try tree.treeOrder(root, child_a), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a, root), .gt);
    try std.testing.expectEqual(try tree.treeOrder(root, child_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_b, root), .gt);

    // 13. Create a very deep tree to test performance with nodes at many different levels
    var deep_node = child_b_b_a;
    var deep_nodes = [_]Node.NodeId{undefined} ** 10;

    for (0..10) |i| {
        deep_nodes[i] = try tree.createNode();
        try tree.appendChild(deep_node, deep_nodes[i]);
        deep_node = deep_nodes[i];
    }

    // Test deep ancestor relationship
    try std.testing.expectEqual(try tree.treeOrder(child_b_b, deep_nodes[9]), .lt);
    try std.testing.expectEqual(try tree.treeOrder(deep_nodes[9], child_b_b), .gt);
    try std.testing.expectEqual(try tree.treeOrder(deep_nodes[0], deep_nodes[9]), .lt);
    try std.testing.expectEqual(try tree.treeOrder(deep_nodes[9], deep_nodes[0]), .gt);

    // 14. Test after more complex tree modifications
    // Move a subtree to another part of the tree
    tree.removeChild(child_b_a, child_a_b);
    try tree.appendChild(deep_nodes[5], child_a_b);

    try std.testing.expectEqual(try tree.treeOrder(deep_nodes[4], child_a_b), .lt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b, deep_nodes[6]), .gt);
    try std.testing.expectEqual(try tree.treeOrder(child_a_b_a, deep_nodes[9]), .gt);
}
