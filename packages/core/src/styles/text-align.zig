const std = @import("std");
const utils = @import("utils.zig");

const MemberType = @import("../layout/utils/comptime.zig").MemberType;
pub const TextAlign = enum {
    start,
    end,
    left,
    right,
    center,
    // justify,
    inherit,
};
pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(TextAlign) {
    return utils.parseEnum(TextAlign, src, pos) orelse error.InvalidSyntax;
}
