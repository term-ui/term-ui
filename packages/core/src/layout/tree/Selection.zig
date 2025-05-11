const std = @import("std");
const Range = @import("Range.zig");
const BoundaryPoint = @import("./BoundaryPoint.zig");
const Tree = @import("./Tree.zig");
const Node = @import("./Node.zig");

range_id: Range.Id,
direction: Direction,
pub const Id = Range.Id;

pub const Direction = enum {
    forward,
    backward,
    none,
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
    std.debug.print("setAnchor {any}\n", .{anchor});
    try self.setRange(tree, anchor, current_focus);
}
pub fn setFocus(self: *Self, tree: *Tree, focus: BoundaryPoint) !void {
    std.debug.print("setFocus {any}\n", .{focus});
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
    right,
    left,
    both,
};

pub const ExtendGranularity = enum {
    character,
    word,
    line,
    lineboundary,
    paragraphboundary,
    documentboundary,
};

pub fn extendBy(
    self: *Self,
    tree: *Tree,
    granularity: ExtendGranularity,
    direction: ExtendDirection,
) !void {
    _ = self; // autofix
    _ = tree; // autofix
    _ = granularity; // autofix
    _ = direction; // autofix
}
