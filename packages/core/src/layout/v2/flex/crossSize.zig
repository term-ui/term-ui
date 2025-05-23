const std = @import("std");
const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
const types = @import("types.zig");
const flexItems = @import("flexItems.zig");

/// Determine the hypothetical cross size of each item.
pub fn determineHypotheticalCrossSize(
    context: *mod.LayoutContext,
    line: *types.FlexLine,
    constants: *types.AlgoConstants,
    available_space: mod.constants.AvailableSpacePoint,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    for (line.items) |*item| {
        const target_main_size = dir.getMain(item.target_size) orelse 0;
        const child_known_dimensions = if (dir.is_row)
            mod.CSSMaybePoint{ .x = target_main_size, .y = null }
        else
            mod.CSSMaybePoint{ .x = null, .y = target_main_size };

        const child_layout = try mod.performChildLayout(
            context,
            item.node_id,
            child_known_dimensions,
            constants.node_inner_size,
            available_space,
            .inherent_size,
            .{ .start = false, .end = false },
        );

        item.hypothetical_inner_size = if (dir.is_row)
            mod.CSSPoint{ .x = target_main_size, .y = child_layout.size.y }
        else
            mod.CSSPoint{ .x = child_layout.size.x, .y = target_main_size };

        item.hypothetical_outer_size = mod.CSSPoint{
            .x = item.hypothetical_inner_size.x + item.margin.sumHorizontal(),
            .y = item.hypothetical_inner_size.y + item.margin.sumVertical(),
        };
    }
}

/// Calculate the cross size of each flex line.
pub fn calculateCrossSize(
    lines: *std.ArrayList(types.FlexLine),
    known_dimensions: mod.CSSMaybePoint,
    constants: *types.AlgoConstants,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    for (lines.items) |*line| {
        var max_cross_size: f32 = 0.0;
        
        for (line.items) |*item| {
            const cross_size = dir.getCross(item.hypothetical_outer_size) orelse 0;
            max_cross_size = @max(max_cross_size, cross_size);
        }
        
        line.cross_size = max_cross_size;
    }
    
    // If container cross size is known, distribute space
    if (dir.getCross(known_dimensions)) |container_cross| {
        var total_line_cross_size: f32 = 0.0;
        for (lines.items) |line| {
            total_line_cross_size += line.cross_size;
        }
        
        if (lines.items.len > 0) {
            const cross_gap = dir.getCross(constants.gap) orelse 0;
            total_line_cross_size += cross_gap * @as(f32, @floatFromInt(lines.items.len - 1));
            
            const free_space = container_cross - total_line_cross_size;
            if (free_space > 0.0) {
                const extra_per_line = free_space / @as(f32, @floatFromInt(lines.items.len));
                for (lines.items) |*line| {
                    line.cross_size += extra_per_line;
                }
            }
        }
    }
}

/// Handle 'align-content: stretch'.
pub fn handleAlignContentStretch(
    lines: *std.ArrayList(types.FlexLine),
    known_dimensions: mod.CSSMaybePoint,
    constants: *types.AlgoConstants,
) !void {
    if (constants.align_content != .stretch) return;
    
    const dir = flexItems.DirectionHelper.init(constants.dir);
    const container_cross = dir.getCross(known_dimensions) orelse return;
    
    var total_cross_size: f32 = 0.0;
    for (lines.items) |line| {
        total_cross_size += line.cross_size;
    }
    
    if (lines.items.len > 0) {
        const cross_gap = dir.getCross(constants.gap) orelse 0;
        total_cross_size += cross_gap * @as(f32, @floatFromInt(lines.items.len - 1));
        
        const free_space = container_cross - total_cross_size;
        if (free_space > 0.0) {
            const extra_per_line = free_space / @as(f32, @floatFromInt(lines.items.len));
            for (lines.items) |*line| {
                line.cross_size += extra_per_line;
            }
        }
    }
}

/// Determine the used cross size of each flex item.
pub fn determineUsedCrossSize(
    context: *mod.LayoutContext,
    lines: *std.ArrayList(types.FlexLine),
    constants: *types.AlgoConstants,
) !void {
    _ = context;
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    for (lines.items) |*line| {
        for (line.items) |*item| {
            const cross_size = if (item.align_self == .stretch and dir.getCross(item.size) == null)
                line.cross_size - dir.sumCrossAxis(item.margin)
            else
                dir.getCross(item.hypothetical_inner_size) orelse 0;
                
            item.target_size = if (dir.is_row)
                mod.CSSPoint{ .x = item.target_size.x, .y = cross_size }
            else
                mod.CSSPoint{ .x = cross_size, .y = item.target_size.y };
                
            item.outer_target_size = mod.CSSPoint{
                .x = item.target_size.x + item.margin.sumHorizontal(),
                .y = item.target_size.y + item.margin.sumVertical(),
            };
        }
    }
}