const utils = @import("utils.zig");
const std = @import("std");
const fmt = @import("../fmt.zig");
pub const Length = f32;

pub fn parse(src: []const u8, pos: usize) !utils.Result(Length) {
    const number_with_unit = try utils.eatNumberWithUnit(src, pos);
    const value = std.fmt.parseFloat(f32, number_with_unit.value.value) catch return error.InvalidSyntax;
    if (!number_with_unit.unit.empty() and !number_with_unit.unit.match("px") and !number_with_unit.unit.match("pt")) {
        return error.InvalidSyntax;
    }
    return .{ .value = value, .start = pos, .end = number_with_unit.unit.end };
}

test "length" {
    const length = try parse("10px", 0);
    try std.testing.expectEqual(length.value, 10);
    const rect_length = try utils.parseRectShorthand("10px 20px 30px 40px", 0, parse);
    try std.testing.expectEqual(rect_length.value.top, 10);
    try std.testing.expectEqual(rect_length.value.right, 20);
    try std.testing.expectEqual(rect_length.value.bottom, 30);
    try std.testing.expectEqual(rect_length.value.left, 40);
}
