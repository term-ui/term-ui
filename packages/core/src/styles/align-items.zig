const std = @import("std");
const utils = @import("utils.zig");

const MemberType = @import("../layout/utils/comptime.zig").MemberType;
pub const AlignItems = enum {
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
    /// Items are packed along the center of the cross axis
    center,
    /// Items are aligned such as their baselines align
    baseline,
    /// stretch to fill the container
    stretch,
};
pub fn parse(src: []const u8, pos: usize) !utils.Result(AlignItems) {
    return utils.parseEnum(AlignItems, src, pos) orelse error.InvalidSyntax;
}
