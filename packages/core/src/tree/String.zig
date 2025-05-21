const std = @import("std");
const visible = @import("../uni/string-width.zig").visible;

bytes: std.ArrayListUnmanaged(u8) = .{},
line_breaks: ?std.ArrayListUnmanaged(usize) = .{},

const Self = @This();

pub fn init() Self {
    return Self{};
}

pub fn length(self: *Self) usize {
    return self.bytes.items.len;
}

pub fn slice(self: *Self) []const u8 {
    return self.bytes.items;
}

pub fn countCodepoints(self: *Self) usize {
    return std.unicode.utf8CountCodepoints(self.bytes.items) catch unreachable;
}
pub fn iterCodepoints(self: *Self) std.unicode.Utf8Iterator {
    return std.unicode.Utf8Iterator{ .i = 0, .bytes = self.bytes.items };
}
pub fn append(self: *Self, allocator: std.mem.Allocator, bytes: []const u8) !void {
    try self.bytes.appendSlice(allocator, bytes);
}

pub fn concat(self: *Self, allocator: std.mem.Allocator, other: *Self) !void {
    try self.bytes.appendSlice(allocator, other.bytes.items);
}

pub fn clearRetainingCapacity(self: *Self) void {
    self.bytes.clearRetainingCapacity();
    if (self.line_breaks) |*line_breaks| {
        line_breaks.clearRetainingCapacity();
    }
}
pub fn clearAndFree(self: *Self, allocator: std.mem.Allocator) void {
    self.bytes.clearAndFree(allocator);
    if (self.line_breaks) |*line_breaks| {
        line_breaks.clearAndFree(allocator);
    }
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.bytes.deinit(allocator);
    if (self.line_breaks) |*line_breaks| {
        line_breaks.deinit(allocator);
    }
}
pub fn replace(self: *Self, allocator: std.mem.Allocator, start: usize, count: usize, bytes: []const u8) !void {
    try self.bytes.replaceRange(allocator, start, count, bytes);
}

pub fn measure(self: *Self) f32 {
    return @floatFromInt(visible.width.exclude_ansi_colors.utf8(self.bytes.items));
}

pub fn measureBytes(bytes: []const u8) f32 {
    return @floatFromInt(visible.width.exclude_ansi_colors.utf8(bytes));
}
