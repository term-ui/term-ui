const Point = @import("../point.zig").Point;
const Rect = @import("../rect.zig").Rect;
const std = @import("std");

const Layout = @This();

order: u32 = 0,
location: Point(f32) = .{ .x = 0, .y = 0 },
size: Point(f32) = .{ .x = 0, .y = 0 },
content_size: Point(f32) = .{ .x = 0, .y = 0 },
border: Rect(f32) = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
padding: Rect(f32) = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
scrollbar_size: Point(f32) = .{ .x = 0, .y = 0 },
margin: Rect(f32), // = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },

pub const EMPTY = Layout{
    .location = .{ .x = 0, .y = 0 },
    .size = .{ .x = 0, .y = 0 },
    .content_size = .{ .x = 0, .y = 0 },
    .border = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
    .padding = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
    .margin = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
};

pub fn format(self: Layout, comptime fmt_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt_string; // autofix
    _ = options; // autofix
    try std.fmt.format(writer, "[ loc: ({d}, {d}) size: ({d}, {d}) content_size: ({d}, {d}), scrollbar_size: ({d}, {d}), border: ({d}, {d}, {d}, {d}), padding: ({d}, {d}, {d}, {d}) ]", .{
        self.location.x,
        self.location.y,
        self.size.x,
        self.size.y,
        self.content_size.x,
        self.content_size.y,
        self.scrollbar_size.x,
        self.scrollbar_size.y,
        self.border.top,
        self.border.right,
        self.border.bottom,
        self.border.left,
        self.padding.top,
        self.padding.right,
        self.padding.bottom,
        self.padding.left,
    });
}
pub fn fmt(self: Layout) std.fmt.Formatter(format) {
    return .{ .data = self };
}
pub fn toString(self: Layout) []const u8 {
    return std.fmt.format(
        "[w: {any}, h: {any}, x: {any}, y: {any}, c_w: {any}, c_h: {any}]",
        .{
            self.size.x,
            self.size.y,
            self.location.x,
            self.location.y,
            self.content_size.x,
            self.content_size.y,
        },
    );
}
pub fn print(self: Layout) void {
    // std.debug.print("Layout: {s}\n", .{self.toString()});
    return std.debug.print(
        "[w: {d}, h: {d}, x: {d}, y: {d}, c_w: {d}, c_h: {d}]\n",
        .{
            self.size.x,
            self.size.y,
            self.location.x,
            self.location.y,
            self.content_size.x,
            self.content_size.y,
        },
    );
}
// const Layout = @This();

// order: u32 = 0,
// location: Point(f32) = .{ .x = 0, .y = 0 },
// size: Point(f32) = .{ .x = 0, .y = 0 },
// content_size: Point(f32) = .{ .x = 0, .y = 0 },
// border: Rect(f32) = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
// padding: Rect(f32) = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
// scrollbar_size: Point(f32) = .{ .x = 0, .y = 0 },

pub fn new() Layout {
    return .{};
}
test "Layout.toString" {
    const layout = Layout{
        .order = 0,
        .location = .{ .x = 0, .y = 0 },
        .size = .{ .x = 0, .y = 0 },
        .content_size = .{ .x = 0, .y = 0 },
        .scrollbar_size = .{ .x = 0, .y = 0 },
        .border = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
        .margin = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
        .padding = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
    };
    _ = layout; // autofix

    // layout.print();
    // std.debug.print("Layout: {s}\n", .{layout.fmt()});
    // const expected = "Layout";
    // _ = expected; // autofix
    // const result = layout.toString();
    // _ = result; // autofix
    // // testing.expectEqualStrings(expected, result);
}
