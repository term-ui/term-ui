const std = @import("std");
const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
const types = @import("types.zig");
const measureChildSize = @import("measureChildSize.zig").measureChildSize;

/// Generate anonymous flex items.
///
/// # [9.1. Initial Setup](https://www.w3.org/TR/css-flexbox-1/#box-manip)
///
/// - [**Generate anonymous flex items**](https://www.w3.org/TR/css-flexbox-1/#algo-anon-box) as described in [§4 Flex Items](https://www.w3.org/TR/css-flexbox-1/#flex-items).
pub fn generateAnonymousFlexItems(
    context: *mod.LayoutContext,
    l_node_id: mod.LayoutNode.Id,
    constants: *types.AlgoConstants,
) !std.ArrayList(types.FlexItem) {
    var flex_items = std.ArrayList(types.FlexItem).init(context.allocator);
    const children = context.layout_tree.getChildren(l_node_id);

    for (children, 0..) |child_id, index| {
        // Get style values for this child
        const css_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, child_id, .size);
        const css_min_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, child_id, .min_size);
        const css_max_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, child_id, .max_size);
        const css_margin = context.getStyleValue(css_types.LengthPercentageAutoRect, child_id, .margin);
        const css_padding = context.getStyleValue(css_types.LengthPercentageRect, child_id, .padding);
        const css_border = context.getStyleValue(css_types.LengthPercentageRect, child_id, .border_width);
        const css_inset = context.getStyleValue(css_types.LengthPercentageAutoRect, child_id, .inset);
        const css_position = context.getStyleValue(css_types.Position, child_id, .position);
        const css_display = context.getStyleValue(css_types.Display, child_id, .display);
        const css_overflow = context.getStyleValue(css_types.OverflowPoint, child_id, .overflow);
        const css_aspect_ratio = context.getStyleValue(?f32, child_id, .aspect_ratio);
        const css_flex_grow = context.getStyleValue(f32, child_id, .flex_grow);
        const css_flex_shrink = context.getStyleValue(f32, child_id, .flex_shrink);
        _ = context.getStyleValue(css_types.LengthPercentageAuto, child_id, .flex_basis);
        const css_align_self = context.getStyleValue(?css_types.AlignSelf, child_id, .align_self);
        const css_scrollbar_width = context.getStyleValue(f32, child_id, .scrollbar_width);

        if (css_position == .absolute or css_display.outside == .none) {
            continue;
        }

        // Resolve size values with aspect ratio
        const size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
            .x = mod.math.maybeResolve(css_size.x, constants.node_inner_size.x),
            .y = mod.math.maybeResolve(css_size.y, constants.node_inner_size.y),
        }, css_aspect_ratio);

        const min_size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
            .x = mod.math.maybeResolve(css_min_size.x, constants.node_inner_size.x),
            .y = mod.math.maybeResolve(css_min_size.y, constants.node_inner_size.y),
        }, css_aspect_ratio);

        const max_size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
            .x = mod.math.maybeResolve(css_max_size.x, constants.node_inner_size.x),
            .y = mod.math.maybeResolve(css_max_size.y, constants.node_inner_size.y),
        }, css_aspect_ratio);

        // Resolve padding and border (margin handling below)
        const padding = mod.CSSRect{
            .top = mod.math.maybeResolve(css_padding.top, constants.node_inner_size.x) orelse 0,
            .right = mod.math.maybeResolve(css_padding.right, constants.node_inner_size.x) orelse 0,
            .bottom = mod.math.maybeResolve(css_padding.bottom, constants.node_inner_size.x) orelse 0,
            .left = mod.math.maybeResolve(css_padding.left, constants.node_inner_size.x) orelse 0,
        };

        const border = mod.CSSRect{
            .top = mod.math.maybeResolve(css_border.top, constants.node_inner_size.x) orelse 0,
            .right = mod.math.maybeResolve(css_border.right, constants.node_inner_size.x) orelse 0,
            .bottom = mod.math.maybeResolve(css_border.bottom, constants.node_inner_size.x) orelse 0,
            .left = mod.math.maybeResolve(css_border.left, constants.node_inner_size.x) orelse 0,
        };

        // Resolve margins - but also track whether they're auto
        const margin = mod.CSSRect{
            .top = mod.math.maybeResolve(css_margin.top, constants.node_inner_size.y) orelse 0,
            .right = mod.math.maybeResolve(css_margin.right, constants.node_inner_size.x) orelse 0,
            .bottom = mod.math.maybeResolve(css_margin.bottom, constants.node_inner_size.y) orelse 0,
            .left = mod.math.maybeResolve(css_margin.left, constants.node_inner_size.x) orelse 0,
        };

        const margin_is_auto = mod.CSSRect{
            .top = if (css_margin.top == .auto) 1.0 else 0.0,
            .right = if (css_margin.right == .auto) 1.0 else 0.0,
            .bottom = if (css_margin.bottom == .auto) 1.0 else 0.0,
            .left = if (css_margin.left == .auto) 1.0 else 0.0,
        };

        try flex_items.append(.{
            .node_id = child_id,
            .order = @intCast(index),
            .size = size,
            .min_size = min_size,
            .max_size = max_size,
            .inset = css_inset,
            .margin = margin,
            .margin_is_auto = margin_is_auto,
            .padding = padding,
            .border = border,
            .align_self = css_align_self orelse constants.align_items,
            .overflow = css_overflow,
            .scrollbar_width = css_scrollbar_width,
            .flex_grow = css_flex_grow,
            .flex_shrink = css_flex_shrink,
            .flex_basis = 0, // Will be computed in determineFlexBaseSize
            .inner_flex_basis = 0,
            .violation = 0,
            .frozen = false,

            .resolved_minimum_main_size = 0,
            .hypothetical_inner_size = mod.CSSPoint{ .x = 0, .y = 0 },
            .hypothetical_outer_size = mod.CSSPoint{ .x = 0, .y = 0 },
            .target_size = mod.CSSPoint{ .x = 0, .y = 0 },
            .outer_target_size = mod.CSSPoint{ .x = 0, .y = 0 },
            .content_flex_fraction = 0,
            .baseline = 0,
            .offset_main = 0,
            .offset_cross = 0,
        });
    }

    return flex_items;
}

/// Direction helper struct to handle main/cross axis operations
pub const DirectionHelper = struct {
    direction: css_types.FlexDirection,
    is_row: bool,
    is_column: bool,

    pub fn init(direction: css_types.FlexDirection) DirectionHelper {
        return DirectionHelper{
            .direction = direction,
            .is_row = direction == .row or direction == .row_reverse,
            .is_column = direction == .column or direction == .column_reverse,
        };
    }

    pub fn getMain(self: DirectionHelper, point: mod.CSSMaybePoint) ?f32 {
        return if (self.is_row) point.x else point.y;
    }

    pub fn getCross(self: DirectionHelper, point: mod.CSSMaybePoint) ?f32 {
        return if (self.is_row) point.y else point.x;
    }

    pub fn setMain(self: DirectionHelper, point: mod.CSSMaybePoint, value: ?f32) mod.CSSMaybePoint {
        if (self.is_row) {
            return mod.CSSMaybePoint{ .x = value, .y = point.y };
        } else {
            return mod.CSSMaybePoint{ .x = point.x, .y = value };
        }
    }

    pub fn setCross(self: DirectionHelper, point: mod.CSSMaybePoint, value: ?f32) mod.CSSMaybePoint {
        if (self.is_row) {
            return mod.CSSMaybePoint{ .x = point.x, .y = value };
        } else {
            return mod.CSSMaybePoint{ .x = value, .y = point.y };
        }
    }

    pub fn sumMainAxis(self: DirectionHelper, rect: mod.CSSRect) f32 {
        return if (self.is_row) rect.sumHorizontal() else rect.sumVertical();
    }

    pub fn sumCrossAxis(self: DirectionHelper, rect: mod.CSSRect) f32 {
        return if (self.is_row) rect.sumVertical() else rect.sumHorizontal();
    }

    pub fn getCrossStart(self: DirectionHelper, rect: mod.CSSRect) f32 {
        return if (self.is_row) rect.top else rect.left;
    }
};

/// Determine the flex base size and hypothetical main size of each item.
///
/// # [9.2. Line Length Determination](https://www.w3.org/TR/css-flexbox-1/#line-sizing)
///
/// - [**Determine the flex base size and hypothetical main size of each item:**](https://www.w3.org/TR/css-flexbox-1/#algo-main-item)
pub fn determineFlexBaseSize(
    context: *mod.LayoutContext,
    constants: *types.AlgoConstants,
    available_space: mod.constants.AvailableSpacePoint,
    flex_items: *std.ArrayList(types.FlexItem),
) !void {
    const dir = DirectionHelper.init(constants.dir);

    for (flex_items.items) |*child| {
        const css_flex_basis = context.getStyleValue(css_types.LengthPercentageAuto, child.node_id, .flex_basis);
        const css_overflow = context.getStyleValue(css_types.OverflowPoint, child.node_id, .overflow);

        // Parent size for child sizing
        const cross_axis_parent_size: ?f32 = dir.getCross(constants.node_inner_size);
        const child_parent_size: mod.CSSMaybePoint = if (dir.is_row)
            mod.CSSMaybePoint{ .x = null, .y = cross_axis_parent_size }
        else
            mod.CSSMaybePoint{ .x = cross_axis_parent_size, .y = null };

        // Available space for child sizing
        const cross_axis_margin_sum: f32 = dir.sumCrossAxis(constants.margin);
        const child_min_cross: ?f32 = if (dir.getCross(child.min_size)) |a| a + cross_axis_margin_sum else null;
        const child_max_cross: ?f32 = if (dir.getCross(child.max_size)) |a| a + cross_axis_margin_sum else null;

        const cross_axis_available_space: mod.constants.AvailableSpace = switch (dir.getCross(available_space)) {
            .definite => |d| .{
                .definite = mod.math.maybeClamp(
                    cross_axis_parent_size orelse d,
                    child_min_cross,
                    child_max_cross,
                ) orelse d,
            },
            .min_content => .min_content,
            .max_content => .max_content,
        };

        // Known dimensions for child sizing
        const child_known_dimensions: mod.CSSMaybePoint = blk: {
            const ckd = dir.setMain(child.size, null);
            if (child.align_self == .stretch and dir.getCross(child.size) == null) {
                break :blk dir.setCross(
                    ckd,
                    mod.math.maybeSub(
                        switch (cross_axis_available_space) {
                            .definite => |d| d,
                            else => null,
                        },
                        dir.sumCrossAxis(constants.margin),
                    ),
                );
            }
            break :blk ckd;
        };

        child.flex_basis = flex_basis: {
            // A. If the item has a definite used flex basis, that's the flex base size.
            // B. Handle aspect ratio cases (already resolved in size calculation)
            const flex_basis: ?f32 = mod.math.maybeResolve(css_flex_basis, dir.getMain(constants.node_inner_size));
            const main_size: ?f32 = dir.getMain(child.size);
            if (flex_basis orelse main_size) |value| {
                break :flex_basis value;
            }

            // C-E. Content-based sizing
            const child_available_space = mod.constants.AvailableSpacePoint{
                .x = if (dir.is_row)
                    (if (available_space.x == .min_content) .min_content else .max_content)
                else
                    cross_axis_available_space,
                .y = if (dir.is_row)
                    cross_axis_available_space
                else
                    (if (available_space.y == .min_content) .min_content else .max_content),
            };

            const child_layout = try mod.performChildLayout(
                context,
                child.node_id,
                child_known_dimensions,
                child_parent_size,
                child_available_space,
                .content_size,
                .{ .start = false, .end = false },
            );

            break :flex_basis dir.getMain(mod.CSSMaybePoint{
                .x = child_layout.size.x,
                .y = child_layout.size.y,
            }) orelse 0;
        };

        // Floor flex-basis by the padding_border_sum
        const padding_border_sum: f32 = dir.sumMainAxis(child.padding) + dir.sumMainAxis(child.border);
        child.flex_basis = @max(child.flex_basis, padding_border_sum);

        // The hypothetical main size is the item's flex base size clamped according to its used min and max main sizes
        child.inner_flex_basis = child.flex_basis - dir.sumMainAxis(child.padding) - dir.sumMainAxis(child.border);

        const padding_border_size = mod.CSSPoint{
            .x = child.padding.sumHorizontal() + child.border.sumHorizontal(),
            .y = child.padding.sumVertical() + child.border.sumVertical(),
        };

        const hypothetical_inner_min_main: ?f32 = mod.math.maybeMax(
            dir.getMain(child.min_size),
            dir.getMain(padding_border_size),
        );

        const hypothetical_inner_size: f32 = mod.math.maybeClamp(
            child.flex_basis,
            hypothetical_inner_min_main,
            dir.getMain(child.max_size),
        ) orelse child.flex_basis;

        const hypothetical_outer_size: f32 = hypothetical_inner_size + dir.sumMainAxis(child.margin);

        child.hypothetical_inner_size = if (dir.is_row)
            mod.CSSPoint{ .x = hypothetical_inner_size, .y = child.hypothetical_inner_size.y }
        else
            mod.CSSPoint{ .x = child.hypothetical_inner_size.x, .y = hypothetical_inner_size };

        child.hypothetical_outer_size = if (dir.is_row)
            mod.CSSPoint{ .x = hypothetical_outer_size, .y = child.hypothetical_outer_size.y }
        else
            mod.CSSPoint{ .x = child.hypothetical_outer_size.x, .y = hypothetical_outer_size };

        // Determine resolved minimum main size
        const style_min_main_size: ?f32 = dir.getMain(child.min_size) orelse blk: {
            const auto_min = mod.CSSMaybePoint{
                .x = switch (css_overflow.x) {
                    .visible => 0,
                    else => null,
                },
                .y = switch (css_overflow.y) {
                    .visible => 0,
                    else => null,
                },
            };
            break :blk dir.getMain(auto_min);
        };

        child.resolved_minimum_main_size = style_min_main_size orelse resolved: {
            // Compute min-content size for automatic minimum
            const child_available_space_min = mod.constants.AvailableSpacePoint{
                .x = if (dir.is_row) .min_content else cross_axis_available_space,
                .y = if (dir.is_row) cross_axis_available_space else .min_content,
            };

            const min_content_layout = try mod.performChildLayout(
                context,
                child.node_id,
                mod.CSSMaybePoint.NULL,
                child_parent_size,
                child_available_space_min,
                .content_size,
                .{ .start = false, .end = false },
            );

            break :resolved dir.getMain(mod.CSSMaybePoint{
                .x = min_content_layout.size.x,
                .y = min_content_layout.size.y,
            }) orelse 0;
        };
    }
}
