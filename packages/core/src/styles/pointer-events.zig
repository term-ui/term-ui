const std = @import("std");
const utils = @import("utils.zig");
const Point = @import("../layout/point.zig").Point;

const MemberType = @import("../layout/utils/comptime.zig").MemberType;
pub const PointerEvents = enum(u8) {
    auto,
    none,
};

pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(PointerEvents) {
    return utils.parseEnum(PointerEvents, src, pos) orelse error.InvalidSyntax;
}
