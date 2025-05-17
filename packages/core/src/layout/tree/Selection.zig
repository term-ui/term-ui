const std = @import("std");
const Range = @import("Range.zig");
const BoundaryPoint = @import("./BoundaryPoint.zig");
const Tree = @import("./Tree.zig");
const Node = @import("./Node.zig");
const GraphemeIterator = @import("../../uni/GraphemeBreak.zig").Iterator;
const LineBox = @import("../compute/text/ComputedText.zig").LineBox;
const measureText = @import("../../uni/string-width.zig").visible.width.exclude_ansi_colors.utf8;
range_id: Range.Id,
direction: Direction,
pub const Id = Range.Id;

pub const Direction = enum(i2) {
    forward = 1,
    backward = -1,
    none = 0,
};
const Self = @This();

pub fn getRange(self: Self, tree: *Tree) *Range {
    return tree.live_ranges.getPtr(self.range_id).?;
}

pub fn getAnchor(self: Self, tree: *Tree) BoundaryPoint {
    return switch (self.direction) {
        .forward, .none => self.getRange(tree).start,
        .backward => self.getRange(tree).end,
    };
}

pub fn getFocus(self: Self, tree: *Tree) BoundaryPoint {
    return switch (self.direction) {
        .forward, .none => self.getRange(tree).end,
        .backward => self.getRange(tree).start,
    };
}

pub fn setRange(self: *Self, tree: *Tree, start: BoundaryPoint, end: BoundaryPoint) !void {
    const order = try Range.boundaryPointTreeOrder(tree, start, end);
    switch (order) {
        .lt => {
            var range = self.getRange(tree);
            try range.setStart(tree, start.node_id, start.offset);
            try range.setEnd(tree, end.node_id, end.offset);
            self.direction = .forward;
        },
        .gt => {
            var range = self.getRange(tree);
            try range.setStart(tree, end.node_id, end.offset);
            try range.setEnd(tree, start.node_id, start.offset);
            self.direction = .backward;
        },
        .eq => {
            var range = self.getRange(tree);
            try range.setStart(tree, start.node_id, start.offset);
            try range.setEnd(tree, end.node_id, end.offset);
            self.direction = .none;
        },
    }
}
pub fn setAnchor(self: *Self, tree: *Tree, anchor: BoundaryPoint) !void {
    const current_focus = self.getFocus(tree);
    try self.setRange(tree, anchor, current_focus);
}
pub fn setFocus(self: *Self, tree: *Tree, focus: BoundaryPoint) !void {
    const current_anchor = self.getAnchor(tree);
    try self.setRange(tree, current_anchor, focus);
}
pub fn deleteFromDocument(self: *Self, tree: *Tree) !void {
    const range = self.getRange(tree);
    try range.deleteContents(tree);
    self.direction = .none;
}

pub fn collapseToStart(self: *Self, tree: *Tree) !void {
    const range = self.getRange(tree);

    switch (self.direction) {
        .forward, .none => {
            range.end = range.start;
        },
        .backward => {
            range.start = range.end;
        },
    }
    self.direction = .none;
}

pub fn collapseToEnd(self: *Self, tree: *Tree) !void {
    const range = self.getRange(tree);
    switch (self.direction) {
        .forward, .none => {
            range.start = range.end;
        },
        .backward => {
            range.end = range.start;
        },
    }
    self.direction = .none;
}

pub fn extend(self: *Self, tree: *Tree, node_id: Node.NodeId, offset: ?u32) !void {
    const old_anchor = self.getAnchor(tree);
    try self.setRange(tree, old_anchor, BoundaryPoint{ .node_id = node_id, .offset = offset orelse 0 });
}
pub fn isCollapsed(self: Self) bool {
    return self.direction == .none;
}

pub const ExtendDirection = enum {
    forward,
    backward,
};

pub const ExtendGranularity = enum {
    character,
    word,
    line,
    lineboundary,
    // paragraphboundary,
    documentboundary,
};
pub fn findLineBox(tree: *Tree, focus: BoundaryPoint) ?struct {
    line_index: usize,
    part_index: usize,
    root_node_id: Node.NodeId,
} {
    if (tree.getNodeKind(focus.node_id) != .text) {
        return null;
    }
    // find root
    const root_node_id = findLineBoxAncestor(tree, focus.node_id);
    const computed_style = tree.getComputedText(root_node_id) orelse return null;

    if (computed_style.lines.items.len == 0) {
        return null;
    }

    for (computed_style.lines.items, 0..) |line, i| {
        for (line.parts.items, 0..) |part, j| {
            if (part.node_id == focus.node_id and focus.offset >= part.node_offset and focus.offset < part.node_offset + part.length) {
                return .{ .line_index = i, .part_index = j, .root_node_id = root_node_id };
            }
        }
    }
    return null;
}
pub fn findLineBoxAncestor(tree: *Tree, node_id: Node.NodeId) Node.NodeId {
    var current = node_id;
    // if (tree.getNode(current).style.display.) {
    //     return current;
    // }
    while (tree.getNode(current).parent) |parent| {
        if (!tree.getStyle(parent).display.isInlineFlow()) {
            break;
        }
        current = parent;
    }
    return current;
}

pub fn findInlineLineBox(
    tree: *Tree,
    start_node_id: Node.NodeId,
    root_node_id: Node.NodeId,
    direction: ExtendDirection,
) ?*LineBox {
    if (direction == .forward) {
        var node_iter = tree.createNodeIterator(start_node_id);
        while (node_iter.nextNode()) |node| {
            if (node != root_node_id and !tree.isNodeDescendant(node, root_node_id)) break;
            if (tree.getNode(node).styles.display.outside == .@"inline") {
                const new_root = findLineBoxAncestor(tree, node);
                const new_computed = tree.getComputedText(new_root) orelse return null;
                if (new_computed.lines.items.len > 0) {
                    return &new_computed.lines.items[0];
                }
            }
        }
    } else {
        var node_iter = tree.createNodeIterator(root_node_id);
        _ = node_iter.previousNode(); // skip initial
        while (node_iter.previousNode()) |node| {
            if (node != root_node_id and !tree.isNodeDescendant(node, root_node_id)) break;
            if (tree.getNode(node).styles.display.outside == .@"inline") {
                const new_root = findLineBoxAncestor(tree, node);
                const new_computed = tree.getComputedText(new_root) orelse return null;
                if (new_computed.lines.items.len > 0) {
                    return &new_computed.lines.items[new_computed.lines.items.len - 1];
                }
            }
        }
    }
    return null;
}

pub fn getBoundaryAt(
    tree: *Tree,
    focus: BoundaryPoint,
    granularity: ExtendGranularity,
    direction: ExtendDirection,
    ghost_horizontal_position: ?f32,
) ?BoundaryPoint {
    if (granularity == .documentboundary) {
        if (direction == .forward) {
            var last_root: ?Node.NodeId = null;
            var iter = tree.createNodeIterator(Tree.ROOT_NODE_ID);
            while (iter.nextNode()) |node| {
                if (tree.getStyle(node).display.isInlineFlow()) {
                    if (tree.getNode(node).parent) |parent| {
                        if (!tree.getStyle(parent).display.isInlineFlow()) {
                            last_root = node;
                        }
                    } else {
                        last_root = node;
                    }
                }
            }
            const root = last_root orelse return null;
            const ct = tree.getComputedText(root) orelse return null;
            const last_line = ct.lines.items[ct.lines.items.len - 1];
            const last_part = last_line.parts.getLast();
            return BoundaryPoint{ .node_id = last_part.node_id, .offset = @intCast(last_part.node_offset + last_part.length) };
        } else {
            var first_root: ?Node.NodeId = null;
            var iter = tree.createNodeIterator(Tree.ROOT_NODE_ID);
            while (iter.nextNode()) |node| {
                if (tree.getStyle(node).display.isInlineFlow()) {
                    if (tree.getNode(node).parent) |parent| {
                        if (!tree.getStyle(parent).display.isInlineFlow()) {
                            first_root = node;
                            break;
                        }
                    } else {
                        first_root = node;
                        break;
                    }
                }
            }
            const root = first_root orelse return null;
            const ct = tree.getComputedText(root) orelse return null;
            const first_line = ct.lines.items[0];
            const first_part = first_line.parts.items[0];
            return BoundaryPoint{ .node_id = first_part.node_id, .offset = @intCast(first_part.node_offset) };
        }
    }
    const line_box_indexes = findLineBox(tree, focus) orelse return null;
    const computed_text = tree.getComputedText(line_box_indexes.root_node_id) orelse return null;
    const line = computed_text.lines.items[line_box_indexes.line_index];
    const part = line.parts.items[line_box_indexes.part_index];

    if (granularity == .character) {
        const part_slice = computed_text.slice(part.node_offset, part.node_offset + part.length);
        var grapheme_iter = GraphemeIterator.init(part_slice);
        if (direction == .forward) {
            var abs_offset: usize = part.node_offset;
            while (grapheme_iter.next()) |grapheme| {
                abs_offset += grapheme.len;
                if (abs_offset > focus.offset) {
                    return BoundaryPoint{ .node_id = part.node_id, .offset = @intCast(abs_offset) };
                }
            }
            const last_part = line.parts.getLast();
            return BoundaryPoint{ .node_id = last_part.node_id, .offset = @intCast(last_part.node_offset + last_part.length) };
        } else {
            var abs_offset: usize = part.node_offset;
            var prev_offset: usize = part.node_offset;
            while (grapheme_iter.next()) |grapheme| {
                abs_offset += grapheme.len;
                if (abs_offset >= focus.offset) {
                    return BoundaryPoint{ .node_id = part.node_id, .offset = @intCast(prev_offset) };
                }
                prev_offset = abs_offset;
            }
            const first_part = line.parts.items[0];
            return BoundaryPoint{ .node_id = first_part.node_id, .offset = @intCast(first_part.node_offset) };
        }
    }

    if (granularity == .lineboundary) {
        if (direction == .forward) {
            const last_part = line.parts.getLast();

            return BoundaryPoint{ .node_id = last_part.node_id, .offset = @intCast(last_part.node_offset + last_part.length) };
        }
        const first_part = line.parts.items[0];
        return BoundaryPoint{ .node_id = first_part.node_id, .offset = @intCast(first_part.node_offset) };
    }
    if (granularity == .line) {
        var offset_horizontal_position = line.position.x;
        if (ghost_horizontal_position) |pos| {
            offset_horizontal_position = pos;
        } else {
            for (line.parts.items, 0..) |current, i| {
                if (i == line_box_indexes.part_index) break;
                offset_horizontal_position += current.size.x;
            }
            const part_slice = computed_text.slice(part.node_offset, focus.offset);
            offset_horizontal_position += @floatFromInt(measureText(part_slice));
        }
        const maybe_target_line = findInlineLineBox(tree, focus.node_id, line_box_indexes.root_node_id, direction);
        if (maybe_target_line) |target_line| {
            var pos = target_line.position.x;

            var part_index: usize = 0;

            while (part_index < target_line.parts.items.len) {
                const current_part = target_line.parts.items[part_index];
                if (pos + current_part.size.x >= offset_horizontal_position) {
                    break;
                }
                pos += current_part.size.x;
                part_index += 1;
            }
            const target_part = target_line.parts.items[part_index];
            const part_root = findLineBoxAncestor(tree, target_part.node_id);
            var target_computed_text = tree.getComputedText(part_root) orelse return null;
            const part_slice = target_computed_text.slice(target_part.node_offset, target_part.node_offset + target_part.length);
            var grapheme_iter = GraphemeIterator.init(part_slice);
            var index = target_part.node_offset;
            while (grapheme_iter.next()) |grapheme| {
                const grapheme_width: f32 = @floatFromInt(measureText(grapheme.bytes(part_slice)));
                if (pos + grapheme_width > offset_horizontal_position) {
                    break;
                }
                pos += grapheme_width;
                index += grapheme.len;
            }
            return .{
                .node_id = target_part.node_id,
                .offset = @intCast(index),
            };
        }
        if (direction == .forward) {
            const last = line.parts.getLast();
            return BoundaryPoint{ .node_id = last.node_id, .offset = @intCast(last.node_offset + last.length) };
        }
        if (direction == .backward) {
            const first = line.parts.items[0];
            return BoundaryPoint{ .node_id = first.node_id, .offset = @intCast(first.node_offset) };
        }
    }
    return null;
}
pub fn extendBy(
    self: *Self,
    tree: *Tree,
    granularity: ExtendGranularity,
    direction: ExtendDirection,
) !void {
    const focus = self.getFocus(tree);
    const line_box_indexes = findLineBox(tree, focus) orelse return;
    const computed_text = tree.getComputedText(line_box_indexes.root_node_id) orelse return;
    const line = computed_text.lines.items[line_box_indexes.line_index];
    const part = line.parts.items[line_box_indexes.part_index];
    _ = part; // autofix

    if (granularity == .lineboundary) {
        if (direction == .forward) {
            const last_part = line.parts.getLast();
            try self.setAnchor(tree, BoundaryPoint{ .node_id = last_part.node_id, .offset = last_part.node_offset + last_part.length });
            // self.setRange(tree, focus, BoundaryPoint{ .node_id = part.node_id, .offset = part.node_offset + part.length });
        } else {
            const first_part = line.parts.getFirst();
            try self.setAnchor(tree, BoundaryPoint{ .node_id = first_part.node_id, .offset = first_part.node_offset });
            // self.setRange(tree, focus, BoundaryPoint{ .node_id = part.node_id, .offset = part.node_offset });
        }
    }
    // const part_rect = Canvas.Rect{ .pos = line.position.add(part.position), .size = part.size };

    // if (tree.getNodeKind(focus.node_id) != .text) {
    //     return;
    // }
    // // find root
    // var current = focus.node_id;
    // while (true) {
    //     if (tree.getStyle(current).display.isFlowRoot()) {
    //         break;
    //     }
    //     if (tree.getNode(current).parent) |parent| {
    //         current = parent;
    //     } else {
    //         break;
    //     }
    // }
    // const computed_style = tree.getComputedText(current) orelse return;
    // if (computed_style.lines.items.len == 0) {
    //     return;
    // }
    // var line_index: usize = 0;
    // var part_index: usize = 0;
    // for (computed_style.lines.items, 0..) |line, i| {
    //     for (line.parts.items, 0..) |part, j| {
    //         if (part.node_id == focus.node_id and focus.offset >= part.node_offset and focus.offset < part.node_offset + part.length) {
    //             line_index = i;
    //             part_index = j;
    //             break;
    //         }
    //     }
    //     // if (line.parts.getLastOrNull()) |last_part| {
    //     //     if (last_part.node_offset + last_part.length > focus.offset) {
    //     //         line_index = i;
    //     //         continue;
    //     //     }
    //     //     break;
    //     // }
    // }
    // const line = computed_style.lines.items[line_index];
    // var line_rect = Canvas.Rect{ .pos = line.position, .size = line.size };
    // var hit_position = switch (direction) {
    //     .forward => line_rect.pos.add(.{ .x = line_rect.size.width, .y = 0 }),
    //     .backward => line_rect.pos.sub(.{ .x = 0, .y = line_rect.size.height }),
    // };

}
