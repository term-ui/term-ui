const utils = @import("utils.zig");
const std = @import("std");
pub const Number = f32;

pub fn parse(src: []const u8, pos: usize) !utils.Result(Number) {
    const start = utils.eatWhitespace(src, pos);
    const number = try utils.parseNumber(src, start);
    return .{
        .value = std.fmt.parseFloat(Number, number.value) catch return error.InvalidSyntax,
        .start = start,
        .end = number.end,
    };
}
