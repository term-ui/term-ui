const std = @import("std");
const DocNodeId = @import("../tree/Node.zig").NodeId;
const Array = std.ArrayListUnmanaged;
const HashMap = std.AutoHashMapUnmanaged;

nodes: HashMap(LayoutNode.Id, LayoutNode) = .{},
node_count: LayoutNode.Id = 0,
allocator: std.mem.Allocator,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{ .allocator = allocator };
}
pub fn deinit(self: *Self) void {
    var it = self.nodes.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.nodes.deinit(self.allocator);
}

pub fn createNode(self: *Self, data: LayoutNode.Data) !LayoutNode.Id {
    const id = self.node_count;
    try self.nodes.put(self.allocator, id, LayoutNode{ .id = id, .data = data });
    self.node_count += 1;
    return id;
}
pub fn createTextNode(self: *Self, contents: []const u8) !LayoutNode.Id {
    const node_id = try self.createNode(.{ .text_node = .{} });
    var node = self.getNodePtr(node_id);
    try node.data.text_node.contents.appendSlice(self.allocator, contents);
    return node_id;
}
pub fn appendNode(self: *Self, parent_id: LayoutNode.Id, child_id: LayoutNode.Id) !void {
    const parent = self.getNodePtr(parent_id);
    var list: *Array(LayoutNode.Id) = switch (parent.data) {
        .inline_node => |*n| &n.children,
        .block_container_node => |*n| &n.children,
        .inline_container_node => |*n| &n.children,
        else => return error.InvalidParent,
    };
    try list.append(self.allocator, child_id);
}
pub fn getNodePtr(self: *Self, id: LayoutNode.Id) *LayoutNode {
    return self.nodes.getPtr(id) orelse std.debug.panic("LayoutTree: Node {d} not found", .{id});
}

pub const LayoutNode = struct {
    id: Id,
    data: Data,
    pub const Id = u32;
    pub const Data = union(enum) {
        text_node: TextNode,
        inline_node: InlineNode,
        block_container_node: BlockContainerNode,
        inline_container_node: InlineContainerNode,
    };
    pub fn deinit(self: *LayoutNode, allocator: std.mem.Allocator) void {
        switch (self.data) {
            .text_node => |*node| node.deinit(allocator),
            .inline_node => |*node| node.deinit(allocator),
            .block_container_node => |*node| node.deinit(allocator),
            .inline_container_node => |*node| node.deinit(allocator),
        }
    }
};

pub const TextNode = struct {
    contents: Array(u8) = .{},
    pub fn deinit(self: *TextNode, allocator: std.mem.Allocator) void {
        self.contents.deinit(allocator);
    }
};

pub const InlineNode = struct {
    ref: DocRef,
    is_atomic: bool,
    children: Array(LayoutNode.Id) = .{},
    pub fn deinit(self: *InlineNode, allocator: std.mem.Allocator) void {
        self.children.deinit(allocator);
    }
};

pub const DocRef = union(enum) {
    anonymous,
    doc_node: DocNodeId,
};

pub const BlockContainerNode = struct {
    ref: DocRef,
    children: Array(LayoutNode.Id) = .{},
    pub fn deinit(self: *BlockContainerNode, allocator: std.mem.Allocator) void {
        self.children.deinit(allocator);
    }
    pub fn isAnonymous(self: *BlockContainerNode) bool {
        return self.ref == .anonymous;
    }
};

/// The same as a block container, but all children are inline, which enables inline formatting context.
/// this node also holds the LineBoxes
pub const InlineContainerNode = struct {
    ref: DocRef,
    children: Array(LayoutNode.Id) = .{},
    line_boxes: Array(LineBox) = .{},
    pub fn deinit(self: *InlineContainerNode, allocator: std.mem.Allocator) void {
        self.children.deinit(allocator);
        self.line_boxes.deinit(allocator);
    }
};

pub const LineBox = struct {
    fragments: Array(Fragment) = .{},
    pub const Fragment = struct {
        node: LayoutNode.Id,
        start: usize,
        end: usize,
    };
    pub fn deinit(self: *LineBox, allocator: std.mem.Allocator) void {
        self.fragments.deinit(allocator);
    }
};

fn writeDocRef(writer: std.io.AnyWriter, ref: DocRef) !void {
    switch (ref) {
        .anonymous => try writer.writeAll("anon"),
        .doc_node => |id| try writer.print("doc #{d}", .{id}),
    }
}

fn getChildren(node: *LayoutNode) []const LayoutNode.Id {
    return switch (node.data) {
        .inline_node => |*n| n.children.items,
        .block_container_node => |*n| n.children.items,
        .inline_container_node => |*n| n.children.items,
        else => &[_]LayoutNode.Id{},
    };
}

fn printNodeInternal(self: *Self, node_id: LayoutNode.Id, writer: std.io.AnyWriter, prefix: []const u8, is_root: bool, is_last: bool) !void {
    const node = self.getNodePtr(node_id);

    if (!is_root) {
        try writer.writeAll(prefix);
        if (is_last)
            try writer.writeAll("└── ")
        else
            try writer.writeAll("├── ");
    }

    switch (node.data) {
        .text_node => |text| {
            if (is_root) {
                // root has no prefix
            }
            try writer.print("[{s} #{d}] \"{s}\"", .{ @tagName(node.data), node.id, text.contents.items });
        },
        .inline_node => |inline_node| {
            try writer.print("[{s} #{d} atomic={s} ref=", .{ @tagName(node.data), node.id, if (inline_node.is_atomic) "true" else "false" });
            try writeDocRef(writer, inline_node.ref);
            try writer.print(" children={d}]", .{inline_node.children.items.len});
        },
        .block_container_node => |block| {
            try writer.print("[{s} #{d} ref=", .{ @tagName(node.data), node.id });
            try writeDocRef(writer, block.ref);
            try writer.print(" children={d}]", .{block.children.items.len});
        },
        .inline_container_node => |container| {
            try writer.print("[{s} #{d} ref=", .{ @tagName(node.data), node.id });
            try writeDocRef(writer, container.ref);
            try writer.print(" children={d} lines={d}]", .{ container.children.items.len, container.line_boxes.items.len });
        },
    }

    try writer.writeByte('\n');

    var new_prefix_buf: [256]u8 = undefined;
    var new_prefix_len: usize = 0;
    if (!is_root) {
        std.mem.copyForwards(u8, new_prefix_buf[0..prefix.len], prefix);
        const segment = if (is_last) "    " else "│   ";
        new_prefix_len = prefix.len + segment.len;
        std.mem.copyForwards(u8, new_prefix_buf[prefix.len .. prefix.len + segment.len], segment);
    } else {
        new_prefix_len = 0;
    }
    const new_prefix = new_prefix_buf[0..new_prefix_len];

    const children = getChildren(node);
    for (children, 0..) |child, idx| {
        const last_child = idx == children.len - 1;
        try self.printNodeInternal(child, writer, new_prefix, false, last_child);
    }
}

pub fn printNode(self: *Self, node_id: LayoutNode.Id, writer: std.io.AnyWriter) !void {
    try self.printNodeInternal(node_id, writer, "", true, true);
}
pub fn printRoot(self: *Self, writer: std.io.AnyWriter) !void {
    try self.printNode(0, writer);
}

test "LayoutTree" {
    var tree = Self.init(std.testing.allocator);
    defer tree.deinit();

    const root = try tree.createNode(.{ .block_container_node = .{ .ref = .anonymous } });
    try std.testing.expectEqual(root, 0);

    const container = try tree.createNode(.{ .inline_container_node = .{ .ref = .anonymous } });
    const inline_node_id = try tree.createNode(.{ .inline_node = .{ .ref = .anonymous, .is_atomic = false } });
    const text1 = try tree.createTextNode("abc");
    const text2 = try tree.createTextNode("def");
    const text3 = try tree.createTextNode("zzz");

    try tree.appendNode(root, container);
    try tree.appendNode(root, text3);
    try tree.appendNode(container, inline_node_id);
    try tree.appendNode(inline_node_id, text1);
    try tree.appendNode(inline_node_id, text2);

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    try tree.printRoot(writer);

    const expected =
        \\[block_container_node #0 ref=anon children=2]
        \\├── [inline_container_node #1 ref=anon children=1 lines=0]
        \\│   └── [inline_node #2 atomic=false ref=anon children=2]
        \\│       ├── [text_node #3] "abc"
        \\│       └── [text_node #4] "def"
        \\└── [text_node #5] "zzz"
        \\
    ;
    try std.testing.expectEqualStrings(buf.items, expected);
}
