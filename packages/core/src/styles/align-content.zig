const std = @import("std");
const utils = @import("utils.zig");

const MemberType = @import("../layout/utils/comptime.zig").MemberType;

pub const AlignContent = enum {
    /// Items are packed toward the start of the axis
    start,
    /// Items are packed toward the end of the axis
    end,
    /// Items are packed towards the flex-relative start of the axis.
    ///
    /// For flex containers with flex_direction row_reverse or column_reverse this is equivalent
    /// to end. In all other cases it is equivalent to start.
    flex_start,
    /// Items are packed towards the flex-relative end of the axis.
    ///
    /// For flex containers with flex_direction row_reverse or column_reverse this is equivalent
    /// to start. In all other cases it is equivalent to end.
    flex_end,
    /// Items are centered around the middle of the axis
    center,
    /// Items are stretched to fill the container
    stretch,
    /// The first and last items are aligned flush with the edges of the container (no gap)
    /// The gap between items is distributed evenly.
    space_between,
    /// The gap between the first and last items is exactly THE SAME as the gap between items.
    /// The gaps are distributed evenly
    space_evenly,
    /// The gap between the first and last items is exactly HALF the gap between items.
    /// The gaps are distributed evenly in proportion to these ratios.
    space_around,
};
pub fn parse(src: []const u8, pos: usize) !utils.Result(AlignContent) {
    return utils.parseEnum(AlignContent, src, pos) orelse error.InvalidSyntax;
}
