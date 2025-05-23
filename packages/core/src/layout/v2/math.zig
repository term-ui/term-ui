const css_types = @import("../../css/types.zig");
const std = @import("std");
const mod = @import("mod.zig");

pub fn maybeResolve(value: anytype, maybe_container_size: ?f32) ?f32 {
    return switch (@TypeOf(value)) {
        css_types.LengthPercentage => switch (value) {
            .length => |length| length,
            .percentage => |percentage| if (maybe_container_size) |container_size| container_size * percentage / 100 else null,
        },
        css_types.LengthPercentageAuto => switch (value) {
            .length => |length| length,
            .percentage => |percentage| if (maybe_container_size) |container_size| container_size * percentage / 100 else null,
            .auto => null,
        },
        f32 => if (maybe_container_size) |container_size| container_size * value / 100 else null,

        else => @compileError("Unsupported type: " ++ @typeName(@TypeOf(value))),
    };
}

pub fn clamp(value: f32, min: f32, max: f32) f32 {
    return @max(@min(value, max), min);
}
pub fn maybeClamp(maybe_value: ?f32, maybe_min: ?f32, maybe_max: ?f32) ?f32 {
    var value = maybe_value orelse return null;
    if (maybe_max) |max| value = @min(value, max);
    if (maybe_min) |min| value = @max(value, min);
    return value;
}
pub fn maybeMax(maybe_value: ?f32, maybe_other: ?f32) ?f32 {
    if (maybe_value) |value| {
        if (maybe_other) |other| {
            return @max(value, other);
        }
    }
    return maybe_value;
}
pub fn maybeMin(maybe_value: ?f32, maybe_other: ?f32) ?f32 {
    if (maybe_value) |value| {
        if (maybe_other) |other| {
            return @min(value, other);
        }
    }
    return maybe_value;
}
pub fn maybeMul(maybe_value: ?f32, maybe_other: ?f32) ?f32 {
    if (maybe_value) |value| {
        if (maybe_other) |other| {
            return value * other;
        }
    }
    return maybe_value;
}

pub fn maybeDiv(maybe_value: ?f32, maybe_other: ?f32) ?f32 {
    if (maybe_value) |value| {
        if (maybe_other) |other| {
            return value / other;
        }
    }
    return maybe_value;
}

pub fn maybeSub(maybe_value: ?f32, maybe_other: ?f32) ?f32 {
    if (maybe_value) |value| {
        if (maybe_other) |other| {
            return value - other;
        }
    }
    return maybe_value;
}
pub fn maybeAdd(maybe_value: ?f32, maybe_other: ?f32) ?f32 {
    if (maybe_value) |value| {
        if (maybe_other) |other| {
            return value + other;
        }
    }
    return maybe_value;
}
pub fn orZero(maybe_value: ?f32) f32 {
    return maybe_value orelse 0;
}

pub fn maybeApplyAspectRatio(self: mod.CSSMaybePoint, aspect_ratio: ?f32) mod.CSSMaybePoint {
    if (aspect_ratio) |ratio| {
        if (self.x == null and self.y == null) {
            return self;
        }
        if (self.x) |w| {
            return .{ .x = w, .y = w / ratio };
        } else if (self.y) |h| {
            return .{ .x = h * ratio, .y = h };
        }
    }
    return self;
}
