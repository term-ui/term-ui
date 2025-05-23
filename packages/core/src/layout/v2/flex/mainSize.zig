const std = @import("std");
const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
const types = @import("types.zig");
const flexItems = @import("flexItems.zig");
const measureChildSize = @import("measureChildSize.zig").measureChildSize;

/// Determine the container's main size (if not already known)
pub fn determineContainerMainSize(
    context: *mod.LayoutContext,
    available_space: mod.constants.AvailableSpacePoint,
    lines: *std.ArrayList(types.FlexLine),
    constants: *types.AlgoConstants,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);

    const main_content_box_inset: f32 = dir.sumMainAxis(constants.content_box_inset);
    const main_available_space = if (dir.is_row) available_space.x else available_space.y;

    const outer_main_size: f32 = dir.getMain(constants.node_outer_size) orelse blk: {
        switch (main_available_space) {
            .definite => |definite| {
                var longest_line_length: f32 = 0.0;
                for (lines.items) |*line| {
                    var line_size: f32 = line.sumAxisGaps(dir.getMain(constants.gap) orelse 0);

                    for (line.items) |*child| {
                        const padding_border_sum = dir.sumMainAxis(child.padding) + dir.sumMainAxis(child.border);
                        line_size += @max(child.flex_basis + dir.sumMainAxis(child.margin), padding_border_sum);
                    }

                    longest_line_length = @max(longest_line_length, line_size);
                }

                const size = longest_line_length + main_content_box_inset;

                if (lines.items.len > 1) {
                    break :blk @max(size, definite);
                }
                break :blk size;
            },
            .min_content => {
                if (constants.is_wrap) {
                    var longest_line_length: f32 = 0.0;
                    for (lines.items) |*line| {
                        var line_size = line.sumAxisGaps(dir.getMain(constants.gap) orelse 0);

                        for (line.items) |*child| {
                            const padding_border_sum = dir.sumMainAxis(child.padding) + dir.sumMainAxis(child.border);
                            line_size += @max(child.flex_basis + dir.sumMainAxis(child.margin), padding_border_sum);
                        }

                        longest_line_length = @max(longest_line_length, line_size);
                    }

                    break :blk longest_line_length + main_content_box_inset;
                }
                
                // Fall through to max_content calculation
                var main_size: f32 = 0.0;
                for (lines.items) |*line| {
                    var item_main_size_sum: f32 = 0.0;
                    for (line.items) |*item| {
                        item_main_size_sum += try computeContentContribution(context, item, constants, available_space, &dir);
                    }
                    main_size = @max(main_size, item_main_size_sum + line.sumAxisGaps(dir.getMain(constants.gap) orelse 0));
                }
                break :blk main_size + main_content_box_inset;
            },
            .max_content => {
                var main_size: f32 = 0.0;
                for (lines.items) |*line| {
                    var item_main_size_sum: f32 = 0.0;
                    for (line.items) |*item| {
                        item_main_size_sum += try computeContentContribution(context, item, constants, available_space, &dir);
                    }
                    main_size = @max(main_size, item_main_size_sum + line.sumAxisGaps(dir.getMain(constants.gap) orelse 0));
                }
                break :blk main_size + main_content_box_inset;
            },
        }
    };

    const inner_main_size = outer_main_size - main_content_box_inset;
    constants.inner_container_size = if (dir.is_row)
        mod.CSSPoint{ .x = inner_main_size, .y = constants.inner_container_size.y }
    else
        mod.CSSPoint{ .x = constants.inner_container_size.x, .y = inner_main_size };

    constants.container_size = if (dir.is_row)
        mod.CSSPoint{ .x = outer_main_size, .y = constants.container_size.y }
    else
        mod.CSSPoint{ .x = constants.container_size.x, .y = outer_main_size };

    constants.node_inner_size = if (dir.is_row)
        mod.CSSMaybePoint{ .x = inner_main_size, .y = constants.node_inner_size.y }
    else
        mod.CSSMaybePoint{ .x = constants.node_inner_size.x, .y = inner_main_size };

    constants.node_outer_size = if (dir.is_row)
        mod.CSSMaybePoint{ .x = outer_main_size, .y = constants.node_outer_size.y }
    else
        mod.CSSMaybePoint{ .x = constants.node_outer_size.x, .y = outer_main_size };
}

fn computeContentContribution(
    context: *mod.LayoutContext,
    item: *types.FlexItem,
    constants: *types.AlgoConstants,
    available_space: mod.constants.AvailableSpacePoint,
    dir: *const flexItems.DirectionHelper,
) !f32 {
    const style_min: ?f32 = dir.getMain(item.min_size);
    const style_preferred: ?f32 = dir.getMain(item.size);
    const style_max: ?f32 = dir.getMain(item.max_size);

    const clamping_basis = mod.math.maybeMax(item.flex_basis, style_preferred) orelse item.flex_basis;
    const flex_basis_min: ?f32 = if (item.flex_shrink == 0.0) clamping_basis else null;
    const flex_basis_max: ?f32 = if (item.flex_grow == 0.0) clamping_basis else null;

    const min_main_size = @max(
        mod.math.maybeMax(style_min, flex_basis_min) orelse item.resolved_minimum_main_size,
        item.resolved_minimum_main_size,
    );

    const max_main_size = mod.math.maybeMin(style_max, flex_basis_max) orelse std.math.inf(f32);

    // If the clamping values are such that max <= min, then we can avoid expensive computation
    if (style_preferred) |pref| {
        if (max_main_size <= min_main_size or max_main_size <= pref) {
            return std.math.clamp(pref, min_main_size, max_main_size) + dir.sumMainAxis(item.margin);
        }
    }

    if (max_main_size <= min_main_size) {
        return min_main_size + dir.sumMainAxis(item.margin);
    }

    // Compute the min- or max-content size
    const cross_axis_parent_size: ?f32 = dir.getCross(constants.node_inner_size);
    const cross_axis_margin_sum: f32 = dir.sumCrossAxis(constants.margin);
    const child_min_cross: ?f32 = if (dir.getCross(item.min_size)) |min| min + cross_axis_margin_sum else null;
    const child_max_cross: ?f32 = if (dir.getCross(item.max_size)) |max| max + cross_axis_margin_sum else null;

    const cross_axis_available_space: mod.constants.AvailableSpace = blk: {
        const cross_available = if (dir.is_row) available_space.y else available_space.x;
        switch (cross_available) {
            .definite => |d| break :blk .{
                .definite = mod.math.maybeClamp(
                    cross_axis_parent_size orelse d,
                    child_min_cross,
                    child_max_cross,
                ) orelse d,
            },
            .min_content => break :blk .min_content,
            .max_content => break :blk .max_content,
        }
    };

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

    const child_parent_size = mod.CSSMaybePoint{
        .x = if (dir.is_row) null else cross_axis_parent_size,
        .y = if (dir.is_row) cross_axis_parent_size else null,
    };

    const child_layout = try mod.performChildLayout(
        context,
        item.node_id,
        mod.CSSMaybePoint.NULL,
        child_parent_size,
        child_available_space,
        .inherent_size,
        .{ .start = false, .end = false },
    );

    const content_main_size = (dir.getMain(mod.CSSMaybePoint{
        .x = child_layout.size.x,
        .y = child_layout.size.y,
    }) orelse 0) + dir.sumMainAxis(item.margin);

    // Asymmetrical behavior for row vs column containers
    if (dir.is_row) {
        return mod.math.maybeClamp(content_main_size, min_main_size, max_main_size) orelse content_main_size;
    }

    const main_content_box_inset = dir.sumMainAxis(constants.content_box_inset);
    return @max(
        mod.math.maybeClamp(
            @max(content_main_size, item.flex_basis),
            style_min,
            style_max,
        ) orelse @max(content_main_size, item.flex_basis),
        main_content_box_inset,
    );
}

/// Resolve the flexible lengths of all flex items to find their target main sizes.
pub fn resolveFlexibleLengths(
    _: std.mem.Allocator,
    line: *types.FlexLine,
    constants: *types.AlgoConstants,
    original_gap: mod.CSSPoint,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    // If the sum of the unfrozen flex items' flex factors is less than one,
    // multiply each unfrozen item's flex factor by this sum's reciprocal,
    // so that they would sum to exactly one.
    var total_grow_factor: f32 = 0.0;
    var total_shrink_factor: f32 = 0.0;
    var total_target_size: f32 = 0.0;
    
    for (line.items) |*item| {
        if (!item.frozen) {
            total_grow_factor += item.flex_grow;
            total_shrink_factor += item.flex_shrink * item.inner_flex_basis;
            total_target_size += item.flex_basis;
        }
    }

    const container_inner_main_size = dir.getMain(constants.inner_container_size) orelse 0;
    const gap_sum = line.sumAxisGaps(dir.getMain(original_gap) orelse 0);
    const used_space = total_target_size + gap_sum;
    const free_space = container_inner_main_size - used_space;

    // Determine whether we're growing or shrinking
    const is_growing = free_space > 0.0;
    
    // Freeze items with zero flex factors
    for (line.items) |*item| {
        if (!item.frozen) {
            if (is_growing and item.flex_grow == 0.0) {
                item.target_size = if (dir.is_row)
                    mod.CSSPoint{ .x = item.flex_basis, .y = item.target_size.y }
                else
                    mod.CSSPoint{ .x = item.target_size.x, .y = item.flex_basis };
                item.frozen = true;
            } else if (!is_growing and item.flex_shrink == 0.0) {
                item.target_size = if (dir.is_row)
                    mod.CSSPoint{ .x = item.flex_basis, .y = item.target_size.y }
                else
                    mod.CSSPoint{ .x = item.target_size.x, .y = item.flex_basis };
                item.frozen = true;
            }
        }
    }

    // Distribute free space proportionally
    for (line.items) |*item| {
        if (!item.frozen) {
            var target_main_size: f32 = item.flex_basis;
            
            if (is_growing and total_grow_factor > 0.0) {
                target_main_size += free_space * (item.flex_grow / total_grow_factor);
            } else if (!is_growing and total_shrink_factor > 0.0) {
                const scaled_shrink_factor = item.flex_shrink * item.inner_flex_basis;
                target_main_size += free_space * (scaled_shrink_factor / total_shrink_factor);
            }

            // Clamp to min/max constraints
            const min_main = item.resolved_minimum_main_size;
            const max_main = dir.getMain(item.max_size);
            target_main_size = mod.math.maybeClamp(target_main_size, min_main, max_main) orelse target_main_size;

            item.target_size = if (dir.is_row)
                mod.CSSPoint{ .x = target_main_size, .y = item.target_size.y }
            else
                mod.CSSPoint{ .x = item.target_size.x, .y = target_main_size };
                
            item.outer_target_size = if (dir.is_row)
                mod.CSSPoint{ .x = target_main_size + dir.sumMainAxis(item.margin), .y = item.outer_target_size.y }
            else
                mod.CSSPoint{ .x = item.outer_target_size.x, .y = target_main_size + dir.sumMainAxis(item.margin) };
        }
    }
    
    // TODO: Handle violation checking and adjustment iteration
    // This is a simplified version - the full algorithm includes iterative
    // violation checking and adjustment of frozen items
}