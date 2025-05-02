const std = @import("std");
const utils = @import("utils.zig");

const MemberType = @import("../layout/utils/comptime.zig").MemberType;
pub const TextWrap = enum {
    wrap,
    nowrap,
    inherit,
};
pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(TextWrap) {
    return utils.parseEnum(TextWrap, src, pos) orelse error.InvalidSyntax;
}
