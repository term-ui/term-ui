const std = @import("std");
const Node = @import("../../tree/Node.zig");
const Array = std.ArrayListUnmanaged;
const Self = @This();
const Rect = @import("../../rect.zig").Rect;
const styles = @import("../../../styles/styles.zig");
text: Array(u8) = .{},
lines: Array(Line) = .{},
arena: std.heap.ArenaAllocator,

// Get the allocator from the arena
pub fn getAllocator(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}

const Line = struct {
    parts: Array(TextPart) = .{},
    width: f32 = 0,
    height: f32 = 0,
    allocator: std.mem.Allocator,

    pub fn appendPart(self: *Line, part: TextPart) !void {
        self.height = @max(self.height, part.height + part.margin.top + part.margin.bottom);
        self.width += part.width + part.margin.left + part.margin.right;
        try self.parts.append(self.allocator, part);
    }
};

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: Self) void {
    self.arena.deinit();
}
pub fn createLine(self: *Self) Line {
    return .{
        .width = 0,
        .height = 0,
        .allocator = self.arena.allocator(),
    };
}
pub fn pushLine(self: *Self, line: Line) !void {
    try self.lines.append(self.arena.allocator(), line);
}

pub fn appendLine(self: *Self, width: f32, height: f32) !*Line {
    try self.lines.append(self.arena.allocator(), Line{
        .width = width,
        .height = height,
        .allocator = self.arena.allocator(),
    });
    return &self.lines.items[self.lines.items.len - 1];
}

// Add a TextPart to the most recently added line
pub fn appendTextPart(self: *Self, part: TextPart) !void {
    if (self.lines.items.len == 0) {
        // If no line exists, create one first
        const line = try self.appendLine(0, part.height);
        try line.appendPart(self.arena.allocator(), part);
    } else {
        // Add to the last line
        try self.lines.items[self.lines.items.len - 1].appendPart(self.arena.allocator(), part);
    }
}

pub fn appendPart(self: *Self, part: TextPart) !void {
    // To add parts, you should first create a line with appendLine(), then add parts to that line
    // This method is provided for backward compatibility but is not recommended
    if (self.lines.items.len == 0) {
        // If no lines exist, create one first
        const line = try self.appendLine(0, part.height);
        try line.appendPart(self.arena.allocator(), part);
    } else {
        // Add to the last line
        try self.lines.items[self.lines.items.len - 1].appendPart(self.arena.allocator(), part);
    }
}

pub fn appendText(self: *Self, text: []const u8) !void {
    try self.text.appendSlice(self.arena.allocator(), text);
}

pub const TextPart = struct {
    node_id: Node.NodeId,
    break_type: Segment.BreakType,
    start: usize,
    length: usize,
    width: f32,
    height: f32,
    display: styles.display.Display,
    margin: Rect(f32) = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
    pub fn isInlineText(self: TextPart) bool {
        return self.display.outside == .@"inline" and self.display.inside == .flow;
    }
    pub fn shouldClearLine(self: TextPart) bool {
        return self.display.outside != .@"inline";
    }
};
pub const Segment = struct {
    index: usize,
    text: []const u8,
    break_type: BreakType,
    pub const BreakType = enum {
        mandatory,
        allowed,
        not_allowed,
    };
};
