const std = @import("std");

x: f32,
y: f32,
const Self = @This();
pub const ZERO = Self{ .x = 0, .y = 0 };

inline fn width(self: Self) f32 {
    return self.x;
}

inline fn height(self: Self) f32 {
    return self.y;
}

inline fn isZero(self: Self) bool {
    return self.x == 0 and self.y == 0;
}
pub fn add(self: Self, other: Self) Self {
    return .{
        .x = self.x + other.x,
        .y = self.y + other.y,
    };
}
pub fn sub(self: Self, other: Self) Self {
    return .{
        .x = self.x - other.x,
        .y = self.y - other.y,
    };
}
pub fn mul(self: Self, other: Self) Self {
    return .{
        .x = self.x * other.x,
        .y = self.y * other.y,
    };
}
pub fn div(self: Self, other: Self) Self {
    return .{
        .x = self.x / other.x,
        .y = self.y / other.y,
    };
}
pub fn divBy(self: Self, other: f32) Self {
    return .{
        .x = self.x / other,
        .y = self.y / other,
    };
}
pub fn mulBy(self: Self, other: f32) Self {
    return .{
        .x = self.x * other,
        .y = self.y * other,
    };
}

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    try writer.print("({d}, {d})", .{ self.x, self.y });
}

pub const Maybe = struct {
    x: ?f32,
    y: ?f32,
    pub fn orZero(self: Maybe) Self {
        return .{
            .x = self.x orelse 0,
            .y = self.y orelse 0,
        };
    }
    pub fn format(self: Maybe, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("({?d}, {?d})", .{ self.x, self.y });
    }
};

inline fn swap(self: Self) Self {
    return .{
        .x = self.y,
        .y = self.x,
    };
}

pub fn Of(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}
