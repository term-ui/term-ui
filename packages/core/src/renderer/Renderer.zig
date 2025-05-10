const std = @import("std");
const parsers = @import("../styles/styles.zig");
const Point = @import("../layout/point.zig").Point;
const PointU32 = Point(u32);
const Color = @import("../colors/Color.zig");

const Canvas = @import("Canvas.zig");
const Tree = @import("../layout/tree/Tree.zig");
const NodeId = @import("../layout/tree/Node.zig").NodeId;
const Style = @import("../layout/tree/Style.zig");
const ComputedText = @import("../layout/compute/text/ComputedText.zig");
const debug = @import("../debug.zig");
const logger = std.log.scoped(.renderer);

canvas: Canvas,
node_map: std.ArrayList(NodeId),
size: PointU32,
const Self = @This();

pub const RendererError = error{
    StyleComputationFailed,
    InvalidUtf8,
    CursorPositioningFailed,
    DrawingFailed,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .canvas = try Canvas.init(
            allocator,
            .{ .x = 0, .y = 0 },
            Color.tw.black,
            Color.tw.white,
        ),
        .node_map = std.ArrayList(NodeId).init(allocator),
        .size = .{ .x = 0, .y = 0 },
    };
}

pub fn deinit(self: *Self) void {
    self.canvas.deinit();
    self.node_map.deinit();
}

pub fn drawNodeArea(self: *Self, node_id: NodeId, rect: Canvas.Rect) void {
    const clamped_rect = rect.intersect(self.canvas.mask);
    // Ensure we have valid dimensions to work with
    if (clamped_rect.size.x == 0 or clamped_rect.size.y == 0) return;
    // ensure rect is within the canvas

    const x: u32 = @intFromFloat(@round(clamped_rect.pos.x));
    const y: u32 = @intFromFloat(@round(clamped_rect.pos.y));
    const w: u32 = @intFromFloat(@round(clamped_rect.size.x));
    const h: u32 = @intFromFloat(@round(clamped_rect.size.y));

    // Ensure y + h doesn't overflow
    const max_y = if (y >= self.size.y) y else @min(y + h, self.size.y);

    for (y..max_y) |_y| {
        // Ensure x + w doesn't overflow
        const max_x = if (x >= self.size.x) x else @min(x + w, self.size.x);

        for (x..max_x) |_x| {
            self.node_map.items[_y * self.size.x + _x] = node_id;
        }
    }
}

pub fn getNodeAt(self: *Self, position: Point(f32)) NodeId {
    const x: u32 = @intFromFloat(@round(position.x));
    const y: u32 = @intFromFloat(@round(position.y));
    const index = y * self.size.x + x;
    if (index >= self.node_map.items.len) {
        return 0;
    }
    return self.node_map.items[index];
}

pub fn render(self: *Self, tree: *Tree, writer: std.io.AnyWriter, clear_screen: bool) !void {
    const layout = tree.getLayout(0);

    const x: u32 = @intFromFloat(@round(layout.size.x));
    const y: u32 = @intFromFloat(@round(layout.size.y));

    if (x == 0 or y == 0) {
        return;
    }

    self.size = .{ .x = x, .y = y };
    try self.canvas.resize(.{ .x = x, .y = y });
    try self.node_map.resize(x * y);

    // Initialize all node_map items to 0 (root node)
    for (0..self.node_map.items.len) |i| {
        self.node_map.items[i] = 0;
    }

    // Handle potential style computation errors in renderNode
    self.renderNode(tree, 0, .{ .x = 0, .y = 0 }) catch |err| {
        logger.err("Error during rendering: {any}\n", .{err});
        // Continue with basic rendering even if style computation fails
    };

    try self.canvas.render(writer, clear_screen);
}

pub fn renderNode(self: *Self, tree: *Tree, node_id: NodeId, position: Point(f32)) anyerror!void {
    const node = tree.getNode(node_id);
    const layout = node.layout;

    const style = tree.getComputedStyle(node_id);

    const absolute_position = position.add(layout.location);
    const is_text_root = style.display.isInlineFlow();

    if (!is_text_root) {
        if (style.background_color) |background_color| {
            try self.canvas.drawRectBg(.{
                .pos = absolute_position,
                .size = layout.size,
            }, background_color);
        }
        try self.canvas.drawRectBorder(.{
            .pos = absolute_position,
            .size = layout.size,
        }, style.border_style, style.border_color);
        if (style.pointer_events == .auto) {
            self.drawNodeArea(node_id, .{
                .pos = absolute_position,
                .size = layout.size,
            });
        }
        const children = tree.getChildren(node_id);
        const is_scrollable = style.overflow.y == .scroll or style.overflow.x == .scroll;
        const scroll_offset: Point(f32) = if (is_scrollable) node.scroll_offset else .{ .x = 0, .y = 0 };
        for (children.items) |child| {
            const child_layout = tree.getLayout(child);
            const child_viewport_rect: Canvas.Rect = .{
                .pos = absolute_position.add(child_layout.location).sub(scroll_offset),
                .size = child_layout.size,
            };
            if (!child_viewport_rect.intersectsWith(self.canvas.mask)) {
                logger.info("skipping child {d} outside of the renderable area\n", .{child});
                continue;
            }

            const prev_mask = self.canvas.mask;
            defer self.canvas.mask = prev_mask;
            if (is_scrollable) {
                const inner_rect: Canvas.Rect = .{
                    .pos = .{
                        .x = absolute_position.x + layout.border.left,
                        .y = absolute_position.y + layout.border.top,
                    },
                    .size = layout.size.sub(layout.border.sumAxes()),
                };
                self.canvas.mask = self.canvas.mask.intersect(inner_rect);
            }
            try self.renderNode(tree, child, absolute_position.sub(scroll_offset));
        }

        return;
    }

    const line_start = position.x + layout.location.x;
    _ = line_start; // autofix
    if (is_text_root) {
        var computed_text = tree.getComputedText(node_id) orelse std.debug.panic("text node {d} has no computed text\n", .{node_id});

        for (computed_text.lines.items) |line| {
            for (line.parts.items) |part| {
                const kind = tree.getNodeKind(part.node_id);

                const part_computed_style = tree.getComputedStyle(part.node_id);
                const x = position.x + part.position.x + line.position.x + layout.location.x;
                const y = position.y + part.position.y + line.position.y + layout.location.y;
                const pos: Point(f32) = .{ .x = x, .y = y };
                if (kind == .text) {
                    const str = computed_text.slice(part.start, part.start + part.length);

                    const text_format = Canvas.TextFormat.fromStyle(part_computed_style.font_weight, part_computed_style.font_style, part_computed_style.text_decoration);

                    if (style.background_color) |background_color| {
                        try self.canvas.drawRectBg(.{
                            .pos = pos,
                            .size = .{ .x = part.size.x, .y = part.size.y },
                        }, background_color);
                    }
                    // Draw string with formatting
                    try self.canvas.drawStringFormatted(.{
                        .x = pos.x,
                        .y = pos.y,
                    }, str, part_computed_style.foreground_color, text_format);
                } else {
                    try self.renderNode(
                        tree,
                        part.node_id,
                        pos,
                    );
                }
            }
        }
    }
}

test "rendertree" {
    const allocator = std.testing.allocator;

    var tree = try Tree.parseTree(allocator,
        \\<view 
        \\  style="height:15; width:34;display:block;border-style: solid;gap: 0; text-align: center;"
        \\>
        // \\    <text>Lorem ipsum dolor sit amet, consectetur adibpiscing elit. Aliquam varius justo ac neque maximus lobortis. Nam molestie sit amet est aliquet dictum. Phasellus tincidunt, enim condimentum mattis efficitur, ante erat eleifend eros, in feugiat nisi mauris dignissim libero. Praesent fermentum pharetra sapien, nec dapibus risus. Proin dolor risus, bibendum nec est sed, rutrum consequat mauris. Praesent fermentum mollis sem a vestibulum. Duis sit amet bibendum lorem. Cras eget semper elit. Phasellus eu leo eleifend, consectetur orci vitae, consequat quam.</text>
        \\    <text>Lorem ipsum dolor sit amet, consectetur adibp1  iscing elit. Aliquam varius justo.</text>
        \\    <text>Lorem <view style="width:1;height:2;background-color: blue;display:inline-block;"></view> ipsum dolor d</text>
        \\</view>
    );
    defer tree.deinit();
    const writer = std.io.getStdErr().writer().any();

    var renderer = try init(
        allocator,
    );
    defer renderer.deinit();

    try tree.computeLayout(allocator, .{
        .x = .{
            .definite = 30,
        },
        .y = .max_content,
    });
    std.debug.print("--------------------------------\n", .{});
    // // for (0..10) |_| {
    // //     try writer.print("\n\n", .{});
    // try writer.print("\n\n", .{});
    try renderer.render(&tree, writer, false);
    try writer.print("\n\n", .{});
    // defer tree.deinit();
    // // }
    // try tree.print(writer);
    // for (renderer.canvas.cells.items) |*item| {
    //     std.debug.print("item: {any}\n", .{item});
    // }
    try tree.print(writer);

    // std.debug.print("\n\nlayout:\n{any}\n", .{(layout)});
}
