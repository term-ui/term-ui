const std = @import("std");
const utils = @import("utils.zig");

const MemberType = @import("../layout/utils/comptime.zig").MemberType;
pub const FlexWrap = enum {
    /// Items will not wrap and stay on a single line
    no_wrap,
    /// Items will wrap according to this item's [`FlexDirection`]
    wrap,
    /// Items will wrap in the opposite direction to this item's [`FlexDirection`]
    wrap_reverse,

    const default = FlexWrap.no_wrap;
    pub fn isWrap(self: FlexWrap) bool {
        return self == FlexWrap.wrap or self == FlexWrap.wrap_reverse;
    }
};
pub fn parse(src: []const u8, pos: usize) !utils.Result(FlexWrap) {
    return utils.parseEnum(FlexWrap, src, pos) orelse error.InvalidSyntax;
}
