//! Computes size using styles and measure functions
const std = @import("std");
const Node = @import("../../tree/Node.zig");
const Tree = @import("../../tree/Tree.zig");
const Point = @import("../point.zig").Point;
const Maybe = @import("../utils/Maybe.zig");
const compute_constants = @import("compute_constants.zig");
const LayoutInput = compute_constants.LayoutInput;
const LayoutOutput = compute_constants.LayoutOutput;

const AvailableSpace = compute_constants.AvailableSpace;

pub fn computeLeafLayout(inputs: LayoutInput, node_id: Node.NodeId, tree: *Tree, measurer: anytype) !LayoutOutput {
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

    const arg: Point(?f32) = switch (run_mode) {
        .compute_size => known_dimensions,
        .perform_layout => .{ .x = null, .y = null },
        .perform_hidden_layout => unreachable,
    };
    const measured_size: Point(f32) = measurer(arg, available_space);

    const clamped_size = known_dimensions
        .orElse(node_size)
        .orElse(measured_size.add(content_box_inset.sumAxes()))
        .maybeClamp(node_min_size, node_max_size);

    var size: Point(f32) = .{
        .x = clamped_size.x,
        .y = @max(clamped_size.y, if (aspect_ratio) |ratio| clamped_size.x / ratio else 0.0),
    };

    size = size.maybeMax(padding_border.sumAxes());

    return .{
        .size = size,
        .content_size = measured_size.add(padding.sumAxes()),
        .margins_can_collapse_through = !has_styles_preventing_being_collapsed_through and
            size.y == 0.0 and
            measured_size.y == 0.0,
    };
}
