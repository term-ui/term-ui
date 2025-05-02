const utils = @import("utils.zig");
const parsers = @import("styles.zig");
const std = @import("std");

pub const LengthPercentage = union(enum) {
    length: parsers.length.Length,
    percentage: f32,
    pub const ZERO = LengthPercentage{ .length = 0 };
    const Self = @This();

    pub inline fn maybeResolve(self: Self, parent_size: anytype) @TypeOf(parent_size) {
        switch (@TypeOf(parent_size)) {
            f32, comptime_float => {
                switch (self) {
                    .length => return self.length,
                    .percentage => return @as(f32, parent_size) * self.percentage,
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
                }
            },
            else => @compileError("Unsupported type"),
        }
    }
};

pub fn parse(src: []const u8, pos: usize) !utils.Result(LengthPercentage) {
    const number_with_unit = try utils.eatNumberWithUnit(src, pos);
    const value = std.fmt.parseFloat(f32, number_with_unit.value.value) catch return error.InvalidSyntax;

    if (number_with_unit.unit.match("%")) {
        return .{
            .value = LengthPercentage{ .percentage = value / 100 },
            .start = pos,
            .end = number_with_unit.unit.end,
        };
    }
    const length = try parsers.length.parse(src, pos);
    return .{
        .value = LengthPercentage{ .length = length.value },
        .start = length.start,
        .end = length.end,
    };
}

test "length-percentage" {
    const allocator = std.testing.allocator;
    const length_percentage = try parse(allocator, "10px", 0);
    try std.testing.expectEqual(length_percentage.value, LengthPercentage{ .length = 10 });
    const length_percentage_percentage = try parse(allocator, "10%", 0);
    try std.testing.expectEqual(length_percentage_percentage.value, LengthPercentage{ .percentage = 10 });
}
