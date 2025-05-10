const std = @import("std");
const Node = @import("../../tree/Node.zig");
const Array = std.ArrayListUnmanaged;
const Self = @This();
const Rect = @import("../../rect.zig").Rect;
const styles = @import("../../../styles/styles.zig");
const String = @import("../../tree/String.zig");
const Point = @import("../../point.zig").Point;
data: std.ArrayListUnmanaged(u8) = .{},
lines: Array(LineBox) = .{},
arena: std.heap.ArenaAllocator,

// Get the allocator from the arena
pub fn getAllocator(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}

const LineBox = struct {
    parts: Array(TextPart) = .{},
    content_width: f32 = 0,
    allocator: std.mem.Allocator,
    position: Point(f32) = .{ .x = 0, .y = 0 },
    size: Point(f32) = .{ .x = 0, .y = 0 },
    pub fn appendPart(self: *LineBox, part: TextPart) !void {
        self.size.y = @max(self.size.y, part.size.y + part.margin.top + part.margin.bottom);
        // std.debug.print("part.size {any} {any}\n", .{ part.size, part.position });
        self.content_width += part.size.x + part.margin.left + part.margin.right;
        try self.parts.append(self.allocator, part);
    }
    pub fn alignHorizontally(self: *LineBox, alignment: styles.text_align.TextAlign, container_width: f32) void {
        self.size.x = container_width;
        var x = switch (alignment) {
            // .left => {
            //     self.x = 0;
            // },
            .right => container_width - self.content_width,
            .center => (container_width - self.content_width) / 2,

            else => 0,
        };
        const baseline = self.position.y;
        _ = baseline; // autofix
        for (self.parts.items) |*part| {
            part.position.x = x;
            x += part.size.x + part.margin.left + part.margin.right;
            part.position.y = self.size.y - part.size.y;
        }
    }
};

pub fn length(self: Self) usize {
    return self.data.items.len;
}
// pub fn appendText(self: *Self, text: []const u8) !void {
//     try self.data.appendSlice(self.arena.allocator(), text);
// }
pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: Self) void {
    self.arena.deinit();
}
pub fn createLine(self: *Self) LineBox {
    return .{
        .allocator = self.arena.allocator(),
    };
}
pub fn pushLine(self: *Self, line: LineBox) !void {
    try self.lines.append(self.arena.allocator(), line);
}

pub fn appendLine(self: *Self, width: f32, height: f32) !*LineBox {
    try self.lines.append(self.arena.allocator(), LineBox{
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
    try self.data.appendSlice(self.arena.allocator(), text);
}
pub fn slice(self: Self, start: usize, end: usize) []const u8 {
    return self.data.items[start..end];
}

pub const TextPart = struct {
    node_id: Node.NodeId,
    break_type: Segment.BreakType,
    start: usize,
    length: usize,
    display: styles.display.Display,
    margin: Rect(f32) = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
    position: Point(f32) = .{ .x = 0, .y = 0 },
    size: Point(f32) = .{ .x = 0, .y = 0 },

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
