const utils = @import("utils.zig");
const parsers = @import("styles.zig");
const std = @import("std");

pub const LengthPercentageAuto = union(enum) {
    length: parsers.length.Length,
    percentage: f32,
    auto: void,

    pub const ZERO = LengthPercentageAuto{ .length = 0 };

    const Self = @This();

    pub fn maybeResolve(self: Self, parent_size: anytype) ?f32 {
        const T = @TypeOf(parent_size);
        switch (T) {
            f32, comptime_float => {
                switch (self) {
                    .length => return self.length,
                    .percentage => return @as(f32, parent_size) * self.percentage,
                    .auto => return null,
                }
            },
            ?f32 => {
                switch (self) {
                    .length => return self.length,
                    .percentage => {
                        if (parent_size) |v| {
                            return v * self.percentage;
                        }
                        return null;
                    },
                    .auto => return null,
                }
            },
            else => @compileError("Unsupported type: " ++ @typeName(T)),
        }
    }
};

pub fn parse(src: []const u8, pos: usize) !utils.Result(LengthPercentageAuto) {
    const start = utils.eatWhitespace(src, pos);
    const identifier = utils.consumeIdentifier(src, start);
    if (identifier.match("auto")) {
        return .{
            .value = LengthPercentageAuto{ .auto = {} },
            .start = identifier.start,
            .end = identifier.end,
        };
    }

    const number_with_unit = try utils.eatNumberWithUnit(src, pos);
    const value = std.fmt.parseFloat(f32, number_with_unit.value.value) catch return error.InvalidSyntax;

    if (number_with_unit.unit.match("%")) {
        return .{
            .value = LengthPercentageAuto{ .percentage = value / 100 },
            .start = pos,
            .end = number_with_unit.unit.end,
        };
    }
    const length = try parsers.length.parse(src, pos);
    return .{
        .value = LengthPercentageAuto{ .length = length.value },
        .start = length.start,
        .end = length.end,
    };
}
