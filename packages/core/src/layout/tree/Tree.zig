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
const String = @import("String.zig");

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
pub inline fn getText(self: *Self, id: Node.NodeId) *String {
    return &self.getNode(id).text;
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
    self.getNode(id).styles = style;

    // Mark node dirty for layout
    self.markDirty(id);

    // Invalidate computed styles for this node and descendants
    self.invalidateStyles(id);
}
pub fn setText(self: *Self, id: Node.NodeId, text: []const u8) !void {
    var node = self.getNode(id);
    node.text.clearRetainingCapacity();
    try node.text.append(self.allocator, text);
    self.markDirty(id);
}

pub fn setParent(self: *Self, id: Node.NodeId, parent: ?Node.NodeId) void {
    var node = self.getNode(id);
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

    // try self.nodes.append(self.allocator, .{
    //     .styles = Style.init(self.allocator),
    //     // .children = try std.ArrayList(Node.NodeId).initCapacity(self.allocator, children.len),
    // });
    try self.node_map.put(self.allocator, id, .{
        .id = id,
        .styles = .{},
        // .children = try std.ArrayList(Node.NodeId).initCapacity(self.allocator, children.len),
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
        try writer.print("[{s} #{d}] \"{s}\"\n", .{ @tagName(kind), node_id, self.getText(node_id).bytes.items });
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

// inline fn parseStyle(comptime style_string: []const u8) Style {
//     comptime {
//         var style: Style = .{};
//         var lines = std.mem.splitSequence(u8, style_string, "\n");
//         while (lines.next()) |line| {
//             // const parts = std.mem.splitSequence(u8, line, ": ");
//             const colon_index = std.mem.indexOfScalar(u8, line, ':') orelse @compileError("Invalid style string");
//             const key = line[0..colon_index];
//             const value = line[colon_index + 1 ..];
//             const trimmed_key = std.mem.trim(u8, key, " ");
//             const trimmed_value = std.mem.trim(u8, value, " ");
//             if (std.mem.eql(u8, trimmed_key, "display")) {
//                 if (std.mem.eql(u8, trimmed_value, "block")) {
//                     style.display = .{ .inside = .flow, .outside = .block };
//                 } else if (std.mem.eql(u8, trimmed_value, "flex")) {
//                     style.display = .{ .inside = .flex, .outside = .block };
//                 }
//             } else if (std.mem.eql(u8, trimmed_key, "width")) {
//                 if (std.mem.endsWith(u8, trimmed_value, "%")) {
//                     style.size.x = .{ .percentage = (std.fmt.parseFloat(f32, trimmed_value[0 .. trimmed_value.len - 1]) catch unreachable) / 100 };
//                 } else if (std.mem.eql(u8, trimmed_value, "auto")) {
//                     style.size.x = .{ .auto = {} };
//                 } else {
//                     style.size.x = .{ .length = std.fmt.parseFloat(f32, trimmed_value) catch unreachable };
//                 }
//             } else if (std.mem.eql(u8, trimmed_key, "height")) {
//                 if (std.mem.endsWith(u8, trimmed_value, "%")) {
//                     style.size.y = .{ .percentage = (std.fmt.parseFloat(f32, trimmed_value[0 .. trimmed_value.len - 1]) catch unreachable) / 100 };
//                 } else if (std.mem.eql(u8, trimmed_value, "auto")) {
//                     style.size.y = .{ .auto = {} };
//                 } else {
//                     style.size.y = .{ .length = std.fmt.parseFloat(f32, trimmed_value) catch unreachable };
//                 }
//             }
//             // const key = parts[0];
//             // const value = parts[1];
//             // style.insert(key, value);
//         }
//         return style;
//     }
// }

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
        // const a = style.arena.allocator();

        // if (std.mem.eql(u8, attr.name, "display")) {
        //     style.display = (try s.display.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "position")) {
        //     style.position = (try s.position.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "width")) {
        //     style.size.x = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "height")) {
        //     style.size.y = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "min-width")) {
        //     style.min_size.x = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "min-height")) {
        //     style.min_size.y = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "max-width")) {
        //     style.max_size.x = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "max-height")) {
        //     style.max_size.y = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "top")) {
        //     style.inset.top = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "right")) {
        //     style.inset.right = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "bottom")) {
        //     style.inset.bottom = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "left")) {
        //     style.inset.left = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "overflow-x")) {
        //     style.overflow.x = (try s.overflow.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "overflow-y")) {
        //     style.overflow.y = (try s.overflow.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "overflow")) {
        //     style.overflow = (try s.utils.parseVecShorthand(a, s.overflow.Overflow, attr.value, 0, s.overflow.parse)).value;
        // } else if (std.mem.eql(u8, attr.name, "aspect-ratio")) {
        //     // style.aspect_ratio = (try s.number.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "margin-top")) {
        //     style.margin.top = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "margin-right")) {
        //     style.margin.right = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "margin-bottom")) {
        //     style.margin.bottom = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "margin-left")) {
        //     style.margin.left = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "margin")) {
        //     style.margin = (try s.utils.parseRectShorthand(a, s.length_percentage_auto.LengthPercentageAuto, attr.value, 0, s.length_percentage_auto.parse)).value;
        // } else if (std.mem.eql(u8, attr.name, "padding-top")) {
        //     style.padding.top = (try s.length_percentage.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "padding-right")) {
        //     style.padding.right = (try s.length_percentage.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "padding-bottom")) {
        //     style.padding.bottom = (try s.length_percentage.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "padding-left")) {
        //     style.padding.left = (try s.length_percentage.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "padding")) {
        //     style.padding = (try s.utils.parseRectShorthand(a, s.length_percentage.LengthPercentage, attr.value, 0, s.length_percentage.parse)).value;
        // } else if (std.mem.eql(u8, attr.name, "flex-direction")) {
        //     style.flex_direction = (try s.flex_direction.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "flex-wrap")) {
        //     style.flex_wrap = (try s.flex_wrap.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "flex-basis")) {
        //     style.flex_basis = (try s.length_percentage_auto.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "flex-grow")) {
        //     style.flex_grow = (try s.number.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "flex-shrink")) {
        //     style.flex_shrink = (try s.number.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "align-items")) {
        //     style.align_items = (try s.align_items.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "align-self")) {
        //     style.align_self = (try s.align_items.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "justify-items")) {
        //     style.justify_items = (try s.align_items.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "justify-self")) {
        //     style.justify_self = (try s.align_items.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "align-content")) {
        //     style.align_content = (try s.align_content.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "justify-content")) {
        //     style.justify_content = (try s.align_content.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "color")) {
        //     style.foreground_color = (try s.color.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "background-color")) {
        //     style.background_color = (try s.background.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "text-align")) {
        //     style.text_align = (try s.text_align.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "text-wrap")) {
        //     style.text_wrap = (try s.text_wrap.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "font-weight")) {
        //     style.font_weight = (try s.font_weight.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "font-style")) {
        //     style.font_style = (try s.font_style.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "text-decoration")) {
        //     style.text_decoration = (try s.text_decoration.parse(a, attr.value, 0)).value;
        // } else if (std.mem.eql(u8, attr.name, "gap")) {
        //     style.gap = (try s.utils.parseVecShorthand(a, s.length_percentage.LengthPercentage, attr.value, 0, s.length_percentage.parse)).value;
        // }
    }
    // tree.setStyle(node_id, style);
    for (node.children) |child| {
        switch (child) {
            .element => |el| {
                const child_id = try fromXmlElement(tree, el);
                // try tree.getNode(node_id).appendChild(child_id);
                try tree.appendChild(node_id, child_id);
            },
            .char_data => |text| {
                if (!is_text_node) continue;
                const child_id = try tree.createTextNode(text);
                try tree.appendChild(node_id, child_id);
                // try tree.getNode(node_id).appendChild(child_id);

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
