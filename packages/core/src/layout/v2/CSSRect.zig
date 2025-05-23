const mod = @import("mod.zig");
top: f32 = 0,
left: f32 = 0,
width: f32 = 0,
height: f32 = 0,
const Self = @This();

pub fn sumAxis(self: Self, axis: mod.Axis) f32 {
    return switch (axis) {
        .horizontal => self.left + self.width,
        .vertical => self.top + self.height,
    };
}

pub fn sumHorizontal(self: Self) f32 {
    return self.left + self.width;
}

pub fn sumVertical(self: Self) f32 {
    return self.top + self.height;
}

pub const Maybe = struct {
    top: ?f32,
    left: ?f32,
    width: ?f32,
    height: ?f32,
};

pub fn Of(comptime T: type) type {
    return struct {
        top: T,
        left: T,
        width: T,
        height: T,
    };
}
