const std = @import("std");
const Node = @import("../../tree/Node.zig");
const Array = std.ArrayList;
const Point = @import("../../point.zig").Point;
const LayoutOutput = @import("../compute_constants.zig").LayoutOutput;
const AvailableSpace = @import("../compute_constants.zig").AvailableSpace;
const SizingMode = @import("../compute_constants.zig").SizingMode;
const Line = @import("../../line.zig").Line;

const Tree = @import("../../tree/Tree.zig");
const LayoutInput = @import("../compute_constants.zig").LayoutInput;
const Style = @import("../../tree/Style.zig");
const ComputedText = @import("./ComputedText.zig");
const Segment = ComputedText.Segment;
const TextPart = ComputedText.TextPart;
const visible = @import("../../string-width.zig").visible;
const Maybe = @import("../../utils/Maybe.zig");
const assert = std.debug.assert;
const logger = std.log.scoped(.compute_text_layout);
const perform_child_layout = @import("../perform_child_layout.zig").perform_child_layout;
const LineBreak = @import("../../../uni/LineBreak.zig");

inline fn collect(T: type, allocator: std.mem.Allocator, iterator: anytype) !Array(T) {
    var array = Array(T).init(allocator);
    while (iterator.next()) |item| {
        try array.append(item);
    }
    return array;
}

// bg
const rainbow = [_][]const u8{
    "\x1b[41m",
    "\x1b[42m",
    "\x1b[43m",
    "\x1b[44m",
    "\x1b[45m",
};

pub fn computeTextLayout(allocator: std.mem.Allocator, node_id: Node.NodeId, tree: *Tree, inputs: LayoutInput) !LayoutOutput {
    const known_dimensions = inputs.known_dimensions;
    const parent_size = inputs.parent_size;
    const sizing_mode = inputs.sizing_mode;
    const run_mode = inputs.run_mode;
    const style = tree.getComputedStyle(node_id);

    // Resolve node's preferred/min/max sizes (width/heights) against the available space (percentages resolve to pixel values)
    // For content_size mode, we pretend that the node has no size styles as these should be ignored.

    var node_size: Point(?f32) = .{ .x = null, .y = null };
    var node_min_size: Point(?f32) = .{ .x = null, .y = null };
    var node_max_size: Point(?f32) = .{ .x = null, .y = null };
    var aspect_ratio: ?f32 = null;
    if (sizing_mode == .content_size) {
        node_size = known_dimensions;
    } else if (sizing_mode == .inherent_size) {
        aspect_ratio = style.aspect_ratio;
        const style_size = style.size.maybeResolve(parent_size).maybeApplyAspectRatio(aspect_ratio);
        const style_min_size = style.min_size.maybeResolve(parent_size).maybeApplyAspectRatio(aspect_ratio);
        const style_max_size = style.max_size.maybeResolve(parent_size);

        node_size = known_dimensions.orElse(style_size);
        node_min_size = style_min_size;
        node_max_size = style_max_size;
    }

    // Note: both horizontal and vertical percentage padding/borders are resolved against the container's inline size (i.e. width).
    // This is not a bug, but is how CSS is specified (see: https://developer.mozilla.org/en-US/docs/Web/CSS/padding#values)
    const margin = style.margin.maybeResolve(parent_size.x).orZero();
    const padding = style.padding.maybeResolve(parent_size.x).orZero();
    const border = style.border.maybeResolve(parent_size.x).orZero();
    const padding_border = padding.add(border);

    // Scrollbar gutters are reserved when the `overflow` property is set to `Overflow::Scroll`.
    // However, the axis are switched (transposed) because a node that scrolls vertically needs
    // *horizontal* space to be reserved for a scrollbar
    const overflow = style.overflow;
    const scrollbar_gutter: Point(f32) = .{
        .x = if (overflow.y == .scroll) style.scrollbar_width else 0,
        .y = if (overflow.x == .scroll) style.scrollbar_width else 0,
    };
    // TODO: make side configurable based on the `direction` property
    var content_box_inset = padding_border;
    content_box_inset.right += scrollbar_gutter.x;
    content_box_inset.bottom += scrollbar_gutter.y;

    const display = style.display;
    const is_block = display.outside == .block and display.inside == .flow_root;

    const has_styles_preventing_being_collapsed_through = !is_block or
        style.overflow.x.isScrollContainer() or
        style.overflow.y.isScrollContainer() or
        style.position == .absolute or
        padding.top > 0.0 or
        padding.bottom > 0.0 or
        border.top > 0.0 or
        border.bottom > 0.0;

    // Return early if both width and height are known

    if (run_mode == .compute_size and has_styles_preventing_being_collapsed_through) {
        if (node_size.intoConcrete()) |size| {
            return .{
                .size = size
                    .maybeClamp(node_min_size, node_max_size)
                    .maybeMax(padding_border.sumAxes()),
            };
        }
    }

    // Compute available space
    const available_space: Point(AvailableSpace) = .{
        .x = blk: {
            var x = if (known_dimensions.x) |v| AvailableSpace.from(v) else inputs.available_space.x;
            x = x.maybeSubtractIfDefinite(margin.sumHorizontal());
            x = x.maybeSet(known_dimensions.x)
                .maybeSet(node_size.x)
                .maybeSet(node_max_size.x);
            switch (x) {
                .definite => |s| {
                    break :blk .{ .definite = Maybe.clamp(
                        s,
                        node_min_size.x,
                        node_max_size.x,
                    ) - content_box_inset.sumHorizontal() };
                },
                else => break :blk x,
            }
        },
        .y = blk: {
            var y = if (known_dimensions.y) |v| AvailableSpace.from(v) else inputs.available_space.y;
            y = y.maybeSubtractIfDefinite(margin.sumVertical());
            y = y.maybeSet(known_dimensions.y)
                .maybeSet(node_size.y)
                .maybeSet(node_max_size.y);
            switch (y) {
                .definite => |s| {
                    break :blk .{ .definite = Maybe.clamp(
                        s,
                        node_min_size.y,
                        node_max_size.y,
                    ) - content_box_inset.sumVertical() };
                },
                else => break :blk y,
            }
        },
    };
    // This object is owned by the tree and will be deallocated when the tree is destroyed.
    // Any allocations made by ComputedText methods are intentionally persistent
    // and will show as "leaks" in memory leak detection tools during tests.
    var computed_text = try tree.createComputedText();
    defer tree.setComputedText(node_id, computed_text);
    const root_style = tree.getComputedStyle(node_id);

    // Use the allocator for temporary calculations
    var parts = Array(TextPart).init(allocator);
    defer parts.deinit();

    var final_parts = Array(TextPart).init(allocator);
    defer final_parts.deinit();

    try collectText(allocator, &computed_text, &parts, node_id, node_id, tree, inputs);

    var linebreak_iter = LineBreak.initAssumeValid(computed_text.text.items);
    var segments = std.ArrayList(Segment).init(allocator);
    defer segments.deinit();
    var i: usize = 0;
    while (linebreak_iter.next()) |linebreak| {
        try segments.append(.{
            .index = i,
            .text = computed_text.text.items[i..linebreak.i],
            .break_type = switch (linebreak.mandatory) {
                true => .mandatory,
                false => .allowed,
            },
        });
        i = linebreak.i;
    }

    if (segments.items.len > 0) {
        segments.items[segments.items.len - 1].break_type = .allowed;
    }

    // Process each part and split according to line breaks
    var current_pos: usize = 0;
    var part_index: usize = 0;

    // First process all segments
    for (segments.items, 0..) |segment, segment_index| {
        _ = segment_index; // autofix

        const segment_end = current_pos + segment.text.len;

        // Process each part that might intersect with this segment
        while (part_index < parts.items.len) {
            var part = parts.items[part_index];
            const part_end = part.start + part.length;

            // Non-inline parts need special handling
            if (!part.display.isInlineFlow()) {
                // If there are already parts in final_parts, ensure the last one gets a mandatory break
                const should_clear_line = part.shouldClearLine();

                // update previous part
                if (should_clear_line and final_parts.items.len > 0) {
                    var prev_part = &final_parts.items[final_parts.items.len - 1];

                    prev_part.break_type = if (should_clear_line) .mandatory else .allowed;
                }

                // Add the non-inline part with mandatory break
                // var block_part = part;
                part.break_type = if (should_clear_line) .mandatory else .allowed;
                try final_parts.append(part);
                part_index += 1;
                continue;
            }

            // This part is before the current segment - skip it
            if (part_end <= current_pos) {
                part_index += 1;
                continue;
            }

            // This part starts after the current segment ends - process next segment
            if (part.start >= segment_end) {
                break;
            }

            // There's overlap - split the part
            const intersection_start = @max(current_pos, part.start);
            const intersection_end = @min(segment_end, part_end);

            if (intersection_end > intersection_start) {
                const node_kind = tree.getNodeKind(part.node_id);
                assert(node_kind == .text);
                const slice = std.mem.trimRight(u8, computed_text.text.items[intersection_start..intersection_end], "\n\r");
                var break_type = segment.break_type;
                if (slice.len < intersection_end - intersection_start) {
                    break_type = .mandatory;
                }

                try final_parts.append(.{
                    .node_id = part.node_id,
                    .start = intersection_start,
                    .length = slice.len,
                    .width = @as(f32, @floatFromInt(measureText(computed_text.text.items[intersection_start..intersection_end]))),
                    .height = part.height,
                    .display = part.display,
                    .break_type = if (intersection_end == segment_end)
                        break_type
                    else
                        .not_allowed,
                });
            }

            // If we've processed the entire part, move to next one
            if (part_end <= segment_end) {
                part_index += 1;
            } else {
                // Otherwise we'll continue with this part in the next segment
                break;
            }
        }

        current_pos = segment_end;
    }

    const max_width = blk: {
        if (root_style.text_wrap == .nowrap) {
            break :blk std.math.floatMax(f32);
        }
        break :blk switch (available_space.x) {
            .definite => |width| width,
            .max_content => std.math.floatMax(f32),
            .min_content => min_content: {
                var word_width: f32 = 0;
                var max_word_width: f32 = 0;
                for (final_parts.items) |part| {
                    word_width += part.width;
                    max_word_width = @max(max_word_width, word_width);
                    if (part.break_type != .not_allowed) word_width = 0;
                }
                break :min_content max_word_width;
            },
        };
    };

    var current_line = computed_text.createLine();
    var height: f32 = 0;
    var width: f32 = 0;
    var prev_break: Segment.BreakType = .not_allowed;
    for (final_parts.items) |part| {
        const new_width = current_line.width + part.width + part.margin.left + part.margin.right;

        if (prev_break == .mandatory or new_width > max_width) {
            // for (current_line.parts.items) |p| std.debug.print("{s}", .{computed_text.text.items[p.start .. p.start + p.length]});

            try computed_text.pushLine(current_line);
            height += current_line.height;
            width = @max(width, current_line.width);

            current_line = computed_text.createLine();
        }
        try current_line.appendPart(part);
        prev_break = part.break_type;
    }
    // for (final_parts.items) |part| {
    //     std.debug.print("'{s}' {s}\n", .{ computed_text.text.items[part.start .. part.start + part.length], @tagName(part.break_type) });
    // }

    if (current_line.parts.items.len > 0) {
        try computed_text.pushLine(current_line);
        height += current_line.height;
        width = @max(width, current_line.width);
    }
    // std.debug.print("width: {d} height: {d}\n", .{ width, height });
    // for (computed_text.lines.items) |line| {
    //     std.debug.print("[line]: width: {d} height: {d} ", .{ line.width, line.height });
    //     for (line.parts.items) |part| {
    //         if (part.isInlineText()) {
    //             std.debug.print("{s}", .{computed_text.text.items[part.start .. part.start + part.length]});
    //         } else {
    //             std.debug.print("[{d}]", .{part.node_id});
    //         }
    //     }
    //     std.debug.print("\n", .{});
    // }

    // Return layout with proper width and height
    // width = switch (available_space.x) {
    //     .definite => |container_width| @max(container_width, width),
    //     else => width,
    // };
    // std.debug.print("width: {d} height: {d} available_width: {}\n", .{ width, height, available_space.x });
    return LayoutOutput{
        .size = .{
            .x = width,
            .y = height,
        },
        .content_size = .{
            .x = width,
            .y = height,
        },
    };
}
fn measureText(text: []const u8) usize {
    return visible.width.exclude_ansi_colors.utf8(text);
}
fn collectText(allocator: std.mem.Allocator, computed_text: *ComputedText, parts_array: *Array(TextPart), node_id: Node.NodeId, root_id: Node.NodeId, tree: *Tree, inputs: LayoutInput) !void {
    tree.setTextRootId(node_id, root_id);
    const display = tree.getComputedStyle(node_id).display;

    var part = TextPart{
        .node_id = node_id,
        .start = computed_text.text.items.len,
        .length = 0,
        .break_type = .not_allowed,
        .display = display,
        .width = 0,
        .height = 0,
    };
    const node_kind = tree.getNodeKind(node_id);
    // if text node or if this is root (parts_array is empty)
    if (node_kind == .text) {
        const start = computed_text.text.items.len;
        try computed_text.appendText(tree.getText(node_id).items);
        part.start = start;
        part.length = tree.getText(node_id).items.len;
        part.width = @as(f32, @floatFromInt(measureText(tree.getText(node_id).items)));
        part.height = 1.0;

        try parts_array.append(part);

        return;
    }
    if (display.isInlineFlow()) {
        for (tree.getChildren(node_id).items) |child| {
            try collectText(allocator, computed_text, parts_array, child, root_id, tree, inputs);
        }
        return;
    }

    if (!display.isInlineFlow()) {
        const measured = try perform_child_layout(
            allocator,
            node_id,
            tree,
            .{ .x = null, .y = null },
            inputs.parent_size,
            inputs.available_space,
            .inherent_size,
            .{ .end = false, .start = false },
        );
        part.width = measured.size.x;
        const style = tree.getComputedStyle(node_id);
        part.margin = style.margin.maybeResolve(inputs.parent_size.x).orZero();
        if (part.display.outside == .@"inline") {
            part.margin.top = @max(part.margin.top, 0);
            part.margin.bottom = @max(part.margin.bottom, 0);
        }

        const layout = tree.getUnroundedLayout(node_id);
        layout.size = measured.size;
        layout.content_size = measured.size;
        // layout.size.x = measured.size.x;
        // layout.size.y = measured.size.y;
        // layout.content_size.x = measured.size.x;
        // layout.content_size.y = measured.size.y;

        // For block elements, use the measured height and ensure it's rounded up
        part.height = @ceil(measured.size.y);
        // std.debug.print("part {s} width={d} height={d}\n", .{ @tagName(part.display.outside), part.width, part.height });
        try parts_array.append(part);
        // try parts_array.append(.{
        //     .node_id = node_id,
        //     .start = text_array.items.len,
        //     .length = 0,
        //     .break_type = .NotAllowed,
        //     .width = measured.size.x,
        //     .height = measured.size.y,
        //     .display = display,
        // });
        // return;
    }
}
test "SegmentIter" {
    // var root = try block(testing_allocator, .{}, .{
    //     // "abc ", "", "def",
    //     "Hello     ",
    //     try span(testing_allocator, .{}, .{"World"}),
    //     // try inlineBlock(testing_allocator, .{}, .{
    //     //     " and universe",
    //     // }),
    //     "",
    //
    //     "!",
    //     try span(testing_allocator, .{}, .{
    //         " and universe",
    //         try span(testing_allocator, .{}, .{"!��"}),
    //     }),
    // });
}
