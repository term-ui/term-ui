const std = @import("std");
const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
const types = @import("types.zig");
const flexItems = @import("flexItems.zig");
const computeAlignmentOffset = @import("computeAlignmentOffset.zig").computeAlignmentOffset;

/// Distribute any remaining free space.
pub fn distributeRemainingFreeSpace(
    lines: *std.ArrayList(types.FlexLine),
    constants: *types.AlgoConstants,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    for (lines.items) |*line| {
        const container_main_size = dir.getMain(constants.inner_container_size) orelse 0;
        var line_main_size: f32 = 0;
        
        for (line.items) |item| {
            line_main_size += dir.getMain(item.outer_target_size) orelse 0;
        }
        
        const main_gap = dir.getMain(constants.gap) orelse 0;
        line_main_size += line.sumAxisGaps(main_gap);
        
        const free_space = container_main_size - line_main_size;
        var current_offset: f32 = 0;
        
        for (line.items, 0..) |*item, i| {
            const is_first = i == 0;
            const alignment_offset = computeAlignmentOffset(
                free_space,
                line.items.len,
                main_gap,
                constants.justify_content,
                constants.dir == .row_reverse or constants.dir == .column_reverse,
                is_first,
            );
            
            item.offset_main = current_offset + alignment_offset;
            current_offset += (dir.getMain(item.outer_target_size) orelse 0) + main_gap;
        }
    }
}

/// Resolve cross-axis auto margins.
pub fn resolveCrossAxisAutoMargins(
    lines: *std.ArrayList(types.FlexLine),
    constants: *types.AlgoConstants,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    for (lines.items) |*line| {
        for (line.items) |*item| {
            const cross_size = dir.getCross(item.target_size) orelse 0;
            const line_cross_size = line.cross_size;
            const non_auto_cross_margin = if (dir.is_row) 
                item.margin.sumVertical() 
            else 
                item.margin.sumHorizontal();
                
            const free_space = line_cross_size - cross_size - non_auto_cross_margin;
            
            // Count auto margins in cross axis
            const auto_margin_count = if (dir.is_row)
                @as(f32, @floatFromInt(@intFromBool(item.margin_is_auto.top == 1.0) + @intFromBool(item.margin_is_auto.bottom == 1.0)))
            else
                @as(f32, @floatFromInt(@intFromBool(item.margin_is_auto.left == 1.0) + @intFromBool(item.margin_is_auto.right == 1.0)));
                
            if (auto_margin_count > 0 and free_space > 0) {
                const auto_margin_size = free_space / auto_margin_count;
                
                if (dir.is_row) {
                    if (item.margin_is_auto.top == 1.0) item.margin.top = auto_margin_size;
                    if (item.margin_is_auto.bottom == 1.0) item.margin.bottom = auto_margin_size;
                } else {
                    if (item.margin_is_auto.left == 1.0) item.margin.left = auto_margin_size;
                    if (item.margin_is_auto.right == 1.0) item.margin.right = auto_margin_size;
                }
            }
        }
    }
}

/// Align flex items along the cross axis.
pub fn alignFlexItemsAlongCrossAxis(
    lines: *std.ArrayList(types.FlexLine),
    constants: *types.AlgoConstants,
) !void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    for (lines.items) |*line| {
        for (line.items) |*item| {
            const cross_size = dir.getCross(item.target_size) orelse 0;
            const line_cross_size = line.cross_size;
            const margin_cross = if (dir.is_row) 
                item.margin.sumVertical() 
            else 
                item.margin.sumHorizontal();
                
            const free_space = line_cross_size - cross_size - margin_cross;
            
            item.offset_cross = switch (item.align_self) {
                .flex_start, .start => if (dir.is_row) item.margin.top else item.margin.left,
                .flex_end, .end => free_space - if (dir.is_row) item.margin.bottom else item.margin.right,
                .center => free_space / 2.0 + if (dir.is_row) item.margin.top else item.margin.left,
                .stretch => if (dir.is_row) item.margin.top else item.margin.left,
                .baseline => if (dir.is_row) item.margin.top else item.margin.left, // Simplified
            };
        }
    }
}

/// Determine the flex container's used cross size.
pub fn determineContainerCrossSize(
    lines: *std.ArrayList(types.FlexLine),
    known_dimensions: mod.CSSMaybePoint,
    constants: *types.AlgoConstants,
) f32 {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    
    if (dir.getCross(known_dimensions)) |cross| {
        return cross;
    }
    
    var total_cross_size: f32 = 0;
    for (lines.items) |line| {
        total_cross_size += line.cross_size;
    }
    
    if (lines.items.len > 1) {
        const cross_gap = dir.getCross(constants.gap) orelse 0;
        total_cross_size += cross_gap * @as(f32, @floatFromInt(lines.items.len - 1));
    }
    
    return total_cross_size + dir.sumCrossAxis(constants.content_box_inset);
}

/// Align all flex lines per align-content.
pub fn alignFlexLinesPerAlignContent(
    lines: *std.ArrayList(types.FlexLine),
    constants: *types.AlgoConstants,
    total_line_cross_size: f32,
) void {
    const dir = flexItems.DirectionHelper.init(constants.dir);
    const container_cross_size = dir.getCross(constants.container_size) orelse return;
    const content_box_cross_inset = dir.sumCrossAxis(constants.content_box_inset);
    const inner_cross_size = container_cross_size - content_box_cross_inset;
    
    const free_space = inner_cross_size - total_line_cross_size;
    var current_offset = dir.getCrossStart(constants.content_box_inset);
    
    for (lines.items, 0..) |*line, i| {
        const is_first = i == 0;
        const alignment_offset = computeAlignmentOffset(
            free_space,
            lines.items.len,
            dir.getCross(constants.gap) orelse 0,
            constants.align_content,
            constants.is_wrap_reverse,
            is_first,
        );
        
        line.offset_cross = current_offset + alignment_offset;
        current_offset += line.cross_size + (dir.getCross(constants.gap) orelse 0);
    }
}