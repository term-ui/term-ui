const styles = @import("styles.zig");
const std = @import("std");
const utils = styles.utils;
const fmt = @import("../fmt.zig");
const ColorStop = styles.color_stop.ColorStop;
// <linear-gradient()> =
//   linear-gradient( [ <linear-gradient-syntax> ] )

// <linear-gradient-syntax> =
//   [ <angle> | <zero> | to <side-or-corner> ]? , <color-stop-list>

// <side-or-corner> =
//   [ left | right ]  ||
//   [ top | bottom ]

// <color-stop-list> =
//   <linear-color-stop> , [ <linear-color-hint>? , <linear-color-stop> ]#?

// <linear-color-stop> =
//   <color> <length-percentage>?

// <linear-color-hint> =
//   <length-percentage>

// <length-percentage> =
//   <length>      |
//   <percentage>

pub const LinearGradient = struct {
    angle: styles.angle.Angle,
    color_stops: styles.color_stop.ColorStopList,
};

pub fn parseAngle(src: []const u8, pos: usize) !?utils.Result(styles.angle.Angle) {
    if (std.ascii.isDigit(src[pos])) {
        return styles.angle.parse(src, pos) catch null;
    }
    var cursor = pos;

    const to = utils.matchIdentifier(src, "to", cursor) orelse return null;

    cursor = to.end;
    cursor = utils.eatWhitespace(src, cursor);
    var horizontal: i8 = 0;
    var vertical: i8 = 0;

    // Loop through at most 2 direction identifiers to handle compound directions
    var direction_count: usize = 0;
    while (direction_count < 2) : (direction_count += 1) {
        const ident = utils.consumeIdentifier(src, cursor);
        if (ident.empty()) {
            break;
        }

        if (ident.match("left")) {
            if (horizontal != 0) {
                return error.InvalidSyntax;
            }
            horizontal = -1;
            cursor = ident.end;
        } else if (ident.match("right")) {
            if (horizontal != 0) {
                return error.InvalidSyntax;
            }
            horizontal = 1;
            cursor = ident.end;
        } else if (ident.match("top")) {
            if (vertical != 0) {
                return error.InvalidSyntax;
            }
            vertical = -1;
            cursor = ident.end;
        } else if (ident.match("bottom")) {
            if (vertical != 0) {
                return error.InvalidSyntax;
            }
            vertical = 1;
            cursor = ident.end;
        } else {
            return error.InvalidSyntax;
        }

        // Skip whitespace between identifiers
        const next_cursor = utils.eatWhitespace(src, cursor);
        if (next_cursor == cursor) {
            // No more whitespace to eat, we're done
            break;
        }
        cursor = next_cursor;
    }

    if (horizontal == 0 and vertical == 0) {
        return error.InvalidSyntax;
    }

    const deg: f32 = blk: {
        if (vertical == -1) {
            if (horizontal == 0) {
                break :blk 0;
            }
            break :blk if (horizontal == 1) 45 else 315;
        }

        if (vertical == 1) {
            if (horizontal == 0) {
                break :blk 180;
            }
            break :blk if (horizontal == 1) 135 else 225;
        }

        if (horizontal == 1) {
            break :blk 90;
        }
        if (horizontal == -1) {
            break :blk 270;
        }
        break :blk 0;
    };
    return .{ .value = deg, .start = pos, .end = cursor };
}

pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(LinearGradient) {
    const start = utils.eatWhitespace(src, pos);
    var cursor = start;
    const fn_call = utils.consumeFnCall(src, cursor);

    if (fn_call.match("linear-gradient(")) {
        cursor = fn_call.end;
        cursor = utils.eatWhitespace(src, cursor);
    } else {
        return error.InvalidSyntax;
    }

    cursor = utils.eatWhitespace(src, cursor);

    // Parse the angle if present
    var angle_value: f32 = 180; // Default angle is to bottom (180deg)
    const angle = try parseAngle(src, cursor);
    if (angle != null) {
        angle_value = angle.?.value;
        cursor = utils.eatWhitespace(src, angle.?.end);

        // There should be a comma after the angle
        if (utils.consumeChar(src, ',', cursor)) |new_cursor| {
            cursor = utils.eatWhitespace(src, new_cursor);
        } else {
            return error.InvalidSyntax;
        }
    }

    // Parse the color stop list
    const color_stops_result = try styles.color_stop.parseColorStopList(src, cursor);
    cursor = color_stops_result.end;
    // eat last )
    cursor = utils.consumeChar(src, ')', cursor) orelse return error.InvalidSyntax;

    // Create the linear gradient
    const gradient = LinearGradient{
        .angle = angle_value,
        .color_stops = color_stops_result.value,
    };

    return .{
        .value = gradient,
        .start = start,
        .end = cursor,
    };
}

test "linear-gradient" {
    const src = "linear-gradient( rgba(255, 255, 255, 0.9), rgba(255, 255, 255, 0.2))";
    const result = try parse(src, 0);
    // try std.testing.expectEqual(result.value.angle, 90);
    try std.testing.expectEqual(result.value.color_stops.len, 2);
    for (result.value.color_stops.slice()) |color_stop| {
        std.debug.print("color_stop: {any}\n", .{color_stop});
    }

    // const src2 = "linear-gradient(to bottom, red, blue)";
    // const result2 = try parse(src2, 0);
    // try std.testing.expectEqual(result2.value.angle, 180);
    // try std.testing.expectEqual(result2.value.color_stops.len, 2);

    // const src3 = "linear-gradient(to bottom right, red, yellow 50%, blue)";

    // const result3 = try parse(src3, 0);
    // try std.testing.expectEqual(result3.value.angle, 135);
    // try std.testing.expectEqual(result3.value.color_stops.len, 3);

    // // Test case with a color hint
    // const src4 = "linear-gradient(90deg, red, 30%, blue)";

    // const result4 = try parse(src4, 0);
    // try std.testing.expectEqual(result4.value.angle, 90);
    // try std.testing.expectEqual(result4.value.color_stops.len, 2);
    // // Verify the hint was applied to the first color stop
    // try std.testing.expect(result4.value.color_stops.slice()[0].hint != null);
    // if (result4.value.color_stops.slice()[0].hint) |hint| {
    //     try std.testing.expect(hint == .percentage);
    //     try std.testing.expectApproxEqAbs(@as(f32, 30), hint.percentage, 0.001);
    // }

    // // Test case with multiple hints
    // const src5 = "linear-gradient(to top, red, 20%, blue, 80%, yellow)";

    // const result5 = try parse(src5, 0);
    // try std.testing.expectEqual(result5.value.angle, 0);
    // try std.testing.expectEqual(result5.value.color_stops.len, 3);
    // // Verify the hints were applied to the correct color stops
    // try std.testing.expect(result5.value.color_stops.slice()[0].hint != null);
    // try std.testing.expect(result5.value.color_stops.slice()[1].hint != null);
    // if (result5.value.color_stops.slice()[0].hint) |hint| {
    //     try std.testing.expect(hint == .percentage);
    //     try std.testing.expectApproxEqAbs(@as(f32, 20), hint.percentage, 0.001);
    // }
    // if (result5.value.color_stops.slice()[1].hint) |hint| {
    //     try std.testing.expect(hint == .percentage);
    //     try std.testing.expectApproxEqAbs(@as(f32, 80), hint.percentage, 0.001);
    // }
}
