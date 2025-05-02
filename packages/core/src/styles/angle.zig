const utils = @import("utils.zig");
const std = @import("std");
const fmt = @import("../fmt.zig");
// in degrees
pub const Angle = f32;

pub fn parse(src: []const u8, pos: usize) !utils.Result(Angle) {
    const number_with_unit = try utils.eatNumberWithUnit(src, pos);
    const value = std.fmt.parseFloat(f32, number_with_unit.value.value) catch return error.InvalidSyntax;
    if (number_with_unit.unit.empty()) {
        if (value == 0) {
            return .{ .value = 0, .start = pos, .end = number_with_unit.unit.end };
        }
        return error.InvalidSyntax;
    }
    if (number_with_unit.unit.match("deg")) {
        return .{ .value = value, .start = pos, .end = number_with_unit.unit.end };
    }
    if (number_with_unit.unit.match("rad")) {
        return .{ .value = value * (@as(f32, std.math.pi) / 180), .start = pos, .end = number_with_unit.unit.end };
    }
    if (number_with_unit.unit.match("grad")) {
        return .{ .value = value * 400, .start = pos, .end = number_with_unit.unit.end };
    }
    if (number_with_unit.unit.match("turn")) {
        return .{ .value = value * 360, .start = pos, .end = number_with_unit.unit.end };
    }

    return error.InvalidSyntax;
}
