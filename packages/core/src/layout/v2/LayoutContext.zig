const DocTree = @import("../../tree/Tree.zig");
const mod = @import("./mod.zig");
const LayoutTree = mod.LayoutTree;
const css_types = @import("../../css/types.zig");
const docFromXml = mod.docFromXml;

const std = @import("std");

layout_tree: *LayoutTree,
doc_tree: *DocTree,
allocator: std.mem.Allocator,

pub fn info(self: *Self, l_node_id: mod.LayoutNode.Id, comptime format: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer().any();
    var current = l_node_id;
    while (true) {
        if (self.layout_tree.getNodePtr(current).parent) |parent_id| {
            current = parent_id;
        } else {
            break;
        }
        writer.writeAll("  ") catch @panic("failed to write");
    }

    writer.print("\x1b[38;5;{d}m", .{1 + l_node_id % 14}) catch @panic("failed to print");
    writer.print("[{s}#{d}] ", .{ @tagName(self.layout_tree.getNodePtr(l_node_id).data), l_node_id }) catch @panic("failed to print");
    writer.print("\x1b[0m", .{}) catch @panic("failed to print");
    writer.print(format, args) catch @panic("failed to print");
    writer.writeAll("\n") catch @panic("failed to write");
}

pub fn setBox(self: *Self, l_node_id: mod.LayoutNode.Id, box: mod.Box) void {
    self.layout_tree.getNodePtr(l_node_id).box = box;
}
pub const StyleProperty = enum {
    margin,
    padding,
    border_width,
    inset,
    size,
    max_size,
    min_size,
    aspect_ratio,
    display,
    position,
    overflow,
    scrollbar_width,
};
const styles = @import("../../styles/styles.zig");
const Styles = @import("../../tree/Style.zig");
fn getLayoutNodeStyles(self: *Self, l_node_id: mod.LayoutNode.Id) ?*Styles {
    const l_node = self.layout_tree.getNodePtr(l_node_id);
    switch (l_node.ref) {
        .doc_node => |doc_node| {
            return self.doc_tree.getStyle(doc_node);
        },
        else => {
            return null;
        },
    }
}

pub fn getChildren(self: *Self, l_node_id: mod.LayoutNode.Id) []const mod.LayoutNode.Id {
    return self.layout_tree.getChildren(l_node_id);
}

pub fn getStyleValue(self: *Self, T: type, l_node_id: mod.LayoutNode.Id, comptime property: StyleProperty) T {
    const maybe_node_styles = self.getLayoutNodeStyles(l_node_id);

    switch (comptime property) {
        .margin => {
            return if (maybe_node_styles) |node_styles| node_styles.margin else css_types.LengthPercentageAutoRect{
                .top = .{ .length = 0 },
                .right = .{ .length = 0 },
                .bottom = .{ .length = 0 },
                .left = .{ .length = 0 },
            };
        },
        .padding => {
            return if (maybe_node_styles) |node_styles| node_styles.padding else css_types.LengthPercentageRect{
                .top = .{ .length = 0 },
                .right = .{ .length = 0 },
                .bottom = .{ .length = 0 },
                .left = .{ .length = 0 },
            };
        },
        .border_width => {
            return if (maybe_node_styles) |node_styles| node_styles.border else css_types.LengthPercentageRect{
                .top = .{ .length = 0 },
                .right = .{ .length = 0 },
                .bottom = .{ .length = 0 },
                .left = .{ .length = 0 },
            };
        },
        .inset => {
            return if (maybe_node_styles) |node_styles| node_styles.inset else css_types.LengthPercentageAutoRect{
                .top = .auto,
                .right = .auto,
                .bottom = .auto,
                .left = .auto,
            };
        },
        .size => {
            return if (maybe_node_styles) |node_styles| node_styles.size else css_types.LengthPercentageAutoPoint{
                .x = .auto,
                .y = .auto,
            };
        },
        .max_size => {
            return if (maybe_node_styles) |node_styles| node_styles.max_size else css_types.LengthPercentageAutoPoint{
                .x = .auto,
                .y = .auto,
            };
        },
        .min_size => {
            return if (maybe_node_styles) |node_styles| node_styles.min_size else css_types.LengthPercentageAutoPoint{
                .x = .auto,
                .y = .auto,
            };
        },
        .position => {
            return if (maybe_node_styles) |node_styles| node_styles.position else styles.position.Position.DEFAULT;
        },
        .display => {
            return if (maybe_node_styles) |node_styles| node_styles.display else styles.display.Display.BLOCK;
        },
        .overflow => {
            return if (maybe_node_styles) |node_styles| node_styles.overflow else css_types.OverflowPoint{
                .x = .visible,
                .y = .visible,
            };
        },
        .aspect_ratio => {
            return if (maybe_node_styles) |node_styles| node_styles.aspect_ratio else @as(?f32, null);
        },
        .scrollbar_width => {
            return if (maybe_node_styles) |node_styles| node_styles.scrollbar_width;
        },
    }
}

const Self = @This();
