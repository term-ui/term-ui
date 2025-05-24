const std = @import("std");
const mod = @import("../mod.zig");
const LayoutContext = mod.LayoutContext;
const LayoutTree = mod.LayoutTree;
const LayoutNode = mod.LayoutNode;
const ContainerContext = mod.ContainerContext;
const CSSMaybePoint = mod.CSSMaybePoint;
const css_types = @import("../../../css/types.zig");

pub fn computeInlineContextLayout(context: *LayoutContext, inputs: ContainerContext, l_node_id: LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult {
    context.info(l_node_id, "computeInlineContextLayout", .{});
    const l_node = context.layout_tree.getNodePtr(l_node_id);
    _ = l_node; // autofix
    const available_space = inputs.available_space;
    const parent_size = inputs.parent_size;

    const maybe_container_size = CSSMaybePoint{
        .x = switch (available_space.x) {
            .definite => available_space.x.definite,
            else => null,
        },
        .y = switch (available_space.y) {
            .definite => available_space.y.definite,
            else => null,
        },
    };
    _ = maybe_container_size; // autofix
    // Get style values
    const css_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, l_node_id, .size);
    const css_min_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, l_node_id, .min_size);
    const css_max_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, l_node_id, .max_size);
    const css_margins = context.getStyleValue(css_types.LengthPercentageAutoRect, l_node_id, .margin);
    const css_padding = context.getStyleValue(css_types.LengthPercentageRect, l_node_id, .padding);
    const css_border = context.getStyleValue(css_types.LengthPercentageRect, l_node_id, .border_width);
    const css_inset = context.getStyleValue(css_types.LengthPercentageAutoRect, l_node_id, .inset);
    _ = css_inset; // autofix
    const css_position = context.getStyleValue(css_types.Position, l_node_id, .position);
    _ = css_position; // autofix
    const css_display = context.getStyleValue(css_types.Display, l_node_id, .display);
    const css_overflow = context.getStyleValue(css_types.OverflowPoint, l_node_id, .overflow);
    _ = css_overflow; // autofix
    const css_aspect_ratio = context.getStyleValue(?f32, l_node_id, .aspect_ratio);

    // Resolve margins
    const margin = mod.CSSRect{
        .top = mod.math.maybeResolve(css_margins.top, parent_size.x) orelse 0,
        .right = mod.math.maybeResolve(css_margins.right, parent_size.x) orelse 0,
        .bottom = mod.math.maybeResolve(css_margins.bottom, parent_size.x) orelse 0,
        .left = mod.math.maybeResolve(css_margins.left, parent_size.x) orelse 0,
    };
    const padding = mod.CSSRect{
        .top = mod.math.maybeResolve(css_padding.top, parent_size.x) orelse 0,
        .right = mod.math.maybeResolve(css_padding.right, parent_size.x) orelse 0,
        .bottom = mod.math.maybeResolve(css_padding.bottom, parent_size.x) orelse 0,
        .left = mod.math.maybeResolve(css_padding.left, parent_size.x) orelse 0,
    };
    const border = mod.CSSRect{
        .top = mod.math.maybeResolve(css_border.top, parent_size.x) orelse 0,
        .right = mod.math.maybeResolve(css_border.right, parent_size.x) orelse 0,
        .bottom = mod.math.maybeResolve(css_border.bottom, parent_size.x) orelse 0,
        .left = mod.math.maybeResolve(css_border.left, parent_size.x) orelse 0,
    };
    const maybe_min_size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
        .x = mod.math.maybeResolve(css_min_size.x, parent_size.x),
        .y = mod.math.maybeResolve(css_min_size.y, parent_size.y),
    }, css_aspect_ratio);

    const maybe_max_size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
        .x = mod.math.maybeResolve(css_max_size.x, parent_size.x),
        .y = mod.math.maybeResolve(css_max_size.y, parent_size.y),
    }, css_aspect_ratio);

    const clamped_style_size = switch (inputs.sizing_mode) {
        .inherent_size => mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
            .x = mod.math.maybeResolve(css_size.x, parent_size.x),
            .y = mod.math.maybeResolve(css_size.y, parent_size.y),
        }, css_aspect_ratio),
        else => mod.CSSMaybePoint.NULL,
    };
    const padding_border_size = mod.CSSPoint{
        .x = padding.sumHorizontal() + border.sumHorizontal(),
        .y = padding.sumVertical() + border.sumVertical(),
    };

    // If both min and max in a given axis are set and max <= min then this determines the size in that axis
    var min_max_definite_size = mod.CSSMaybePoint.NULL;
    if (maybe_min_size.x) |min| if (maybe_max_size.x) |max| if (max <= min) {
        min_max_definite_size.x = min;
    };

    if (maybe_min_size.y) |min| if (maybe_max_size.y) |max| if (max <= min) {
        min_max_definite_size.y = min;
    };

    // Block nodes automatically stretch fit their width to fit available space if available space is definite
    const available_space_based_size = mod.CSSMaybePoint{
        .x = if (css_display.outside != .@"inline") mod.math.maybeSub(switch (available_space.x) {
            .definite => available_space.x.definite,
            else => null,
        }, margin.sumHorizontal()) else null,
        .y = null,
    };

    const styled_based_known_dimensions = mod.CSSMaybePoint{
        .x = mod.math.maybeMax(inputs.known_dimensions.x orelse min_max_definite_size.x orelse clamped_style_size.x orelse available_space_based_size.x, padding_border_size.x),
        .y = mod.math.maybeMax(inputs.known_dimensions.y orelse min_max_definite_size.y orelse clamped_style_size.y orelse available_space_based_size.y, padding_border_size.y),
    };
    if (inputs.run_mode == .compute_size and styled_based_known_dimensions.x != null and styled_based_known_dimensions.y != null) {
        return .{
            .size = .{
                .x = styled_based_known_dimensions.x.?,
                .y = styled_based_known_dimensions.y.?,
            },
        };
    }

    return try computeInner(context, .{
        .known_dimensions = styled_based_known_dimensions,

        // unchanged
        .run_mode = inputs.run_mode,
        .sizing_mode = inputs.sizing_mode,
        .axis = inputs.axis,
        .parent_size = inputs.parent_size,
        .available_space = inputs.available_space,
        .vertical_margins_are_collapsible = inputs.vertical_margins_are_collapsible,
    }, l_node_id);
}

fn computeInner(context: *LayoutContext, inputs: ContainerContext, l_node_id: LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult {
    _ = context; // autofix
    _ = inputs; // autofix
    _ = l_node_id; // autofix
    return .{
        .size = .{ .x = 5, .y = 10 },
    };
}
