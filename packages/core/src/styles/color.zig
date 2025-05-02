pub const utils = @import("utils.zig");
pub const parsers = @import("styles.zig");
pub const Color = @import("../colors/Color.zig");
pub const std = @import("std");
const fmt = @import("../fmt.zig");

pub const NamedColor = enum {
    transparent,

    aliceblue,
    antiquewhite,
    aqua,
    aquamarine,
    azure,
    beige,
    bisque,
    black,
    blanchedalmond,
    blue,
    blueviolet,
    brown,
    burlywood,
    cadetblue,
    chartreuse,
    chocolate,
    coral,
    cornflowerblue,
    cornsilk,
    crimson,
    cyan,
    darkblue,
    darkcyan,
    darkgoldenrod,
    darkgray,
    darkgreen,
    darkgrey,
    darkkhaki,
    darkmagenta,
    darkolivegreen,
    darkorange,
    darkorchid,
    darkred,
    darksalmon,
    darkseagreen,
    darkslateblue,
    darkslategray,
    darkslategrey,
    darkturquoise,
    darkviolet,
    deeppink,
    deepskyblue,
    dimgray,
    dimgrey,
    dodgerblue,
    firebrick,
    floralwhite,
    forestgreen,
    fuchsia,
    gainsboro,
    ghostwhite,
    gold,
    goldenrod,
    gray,
    green,
    greenyellow,
    grey,
    honeydew,
    hotpink,
    indianred,
    indigo,
    ivory,
    khaki,
    lavender,
    lavenderblush,
    lawngreen,
    lemonchiffon,
    lightblue,
    lightcoral,
    lightcyan,
    lightgoldenrodyellow,
    lightgray,
    lightgreen,
    lightgrey,
    lightpink,
    lightsalmon,
    lightseagreen,
    lightskyblue,
    lightslategray,
    lightslategrey,
    lightsteelblue,
    lightyellow,
    lime,
    limegreen,
    linen,
    magenta,
    maroon,
    mediumaquamarine,
    mediumblue,
    mediumorchid,
    mediumpurple,
    mediumseagreen,
    mediumslateblue,
    mediumspringgreen,
    mediumturquoise,
    mediumvioletred,
    midnightblue,
    mintcream,
    mistyrose,
    moccasin,
    navajowhite,
    navy,
    oldlace,
    olive,
    olivedrab,
    orange,
    orangered,
    orchid,
    palegoldenrod,
    palegreen,
    paleturquoise,
    palevioletred,
    papayawhip,
    peachpuff,
    peru,
    pink,
    plum,
    powderblue,
    purple,
    rebeccapurple,
    red,
    rosybrown,
    royalblue,
    saddlebrown,
    salmon,
    sandybrown,
    seagreen,
    seashell,
    sienna,
    silver,
    skyblue,
    slateblue,
    slategray,
    slategrey,
    snow,
    springgreen,
    steelblue,
    tan,
    teal,
    thistle,
    tomato,
    turquoise,
    violet,
    wheat,
    white,
    whitesmoke,
    yellow,
    yellowgreen,
    pub fn toRgb(self: NamedColor) Color {
        return switch (self) {
            .black => comptime Color.fromHex("#000000") orelse unreachable,
            .silver => comptime Color.fromHex("#c0c0c0") orelse unreachable,
            .gray => comptime Color.fromHex("#808080") orelse unreachable,
            .white => comptime Color.fromHex("#ffffff") orelse unreachable,
            .maroon => comptime Color.fromHex("#800000") orelse unreachable,
            .red => comptime Color.fromHex("#ff0000") orelse unreachable,
            .purple => comptime Color.fromHex("#800080") orelse unreachable,
            .fuchsia => comptime Color.fromHex("#ff00ff") orelse unreachable,
            .aquamarine => comptime Color.fromHex("#7fffd4") orelse unreachable,
            .limegreen => comptime Color.fromHex("#32cd32") orelse unreachable,
            .green => comptime Color.fromHex("#008000") orelse unreachable,
            .lime => comptime Color.fromHex("#00ff00") orelse unreachable,
            .olive => comptime Color.fromHex("#808000") orelse unreachable,
            .yellow => comptime Color.fromHex("#ffff00") orelse unreachable,
            .navy => comptime Color.fromHex("#000080") orelse unreachable,
            .blue => comptime Color.fromHex("#0000ff") orelse unreachable,
            .teal => comptime Color.fromHex("#008080") orelse unreachable,
            .aqua => comptime Color.fromHex("#00ffff") orelse unreachable,
            .aliceblue => comptime Color.fromHex("#f0f8ff") orelse unreachable,
            .antiquewhite => comptime Color.fromHex("#faebd7") orelse unreachable,
            .azure => comptime Color.fromHex("#f0ffff") orelse unreachable,
            .beige => comptime Color.fromHex("#f5f5dc") orelse unreachable,
            .bisque => comptime Color.fromHex("#ffe4c4") orelse unreachable,
            .blanchedalmond => comptime Color.fromHex("#ffebcd") orelse unreachable,
            .blueviolet => comptime Color.fromHex("#8a2be2") orelse unreachable,
            .brown => comptime Color.fromHex("#a52a2a") orelse unreachable,
            .burlywood => comptime Color.fromHex("#deb887") orelse unreachable,
            .cadetblue => comptime Color.fromHex("#5f9ea0") orelse unreachable,
            .chartreuse => comptime Color.fromHex("#7fff00") orelse unreachable,
            .chocolate => comptime Color.fromHex("#d2691e") orelse unreachable,
            .coral => comptime Color.fromHex("#ff7f50") orelse unreachable,
            .cornflowerblue => comptime Color.fromHex("#6495ed") orelse unreachable,
            .cornsilk => comptime Color.fromHex("#fff8dc") orelse unreachable,
            .crimson => comptime Color.fromHex("#dc143c") orelse unreachable,
            .cyan => comptime Color.fromHex("#00ffff") orelse unreachable,
            .darkblue => comptime Color.fromHex("#00008b") orelse unreachable,
            .darkcyan => comptime Color.fromHex("#008b8b") orelse unreachable,
            .darkgoldenrod => comptime Color.fromHex("#b8860b") orelse unreachable,
            .darkgray => comptime Color.fromHex("#a9a9a9") orelse unreachable,
            .darkgreen => comptime Color.fromHex("#006400") orelse unreachable,
            .darkgrey => comptime Color.fromHex("#a9a9a9") orelse unreachable,
            .darkkhaki => comptime Color.fromHex("#bdb76b") orelse unreachable,
            .darkmagenta => comptime Color.fromHex("#8b008b") orelse unreachable,
            .darkolivegreen => comptime Color.fromHex("#556b2f") orelse unreachable,
            .darkorange => comptime Color.fromHex("#ff8c00") orelse unreachable,
            .darkorchid => comptime Color.fromHex("#9932cc") orelse unreachable,
            .darkred => comptime Color.fromHex("#8b0000") orelse unreachable,
            .darksalmon => comptime Color.fromHex("#e9967a") orelse unreachable,
            .darkseagreen => comptime Color.fromHex("#8fbc8f") orelse unreachable,
            .darkslateblue => comptime Color.fromHex("#483d8b") orelse unreachable,
            .darkslategray => comptime Color.fromHex("#2f4f4f") orelse unreachable,
            .darkslategrey => comptime Color.fromHex("#2f4f4f") orelse unreachable,
            .darkturquoise => comptime Color.fromHex("#00ced1") orelse unreachable,
            .darkviolet => comptime Color.fromHex("#9400d3") orelse unreachable,
            .deeppink => comptime Color.fromHex("#ff1493") orelse unreachable,
            .deepskyblue => comptime Color.fromHex("#00bfff") orelse unreachable,
            .dimgray => comptime Color.fromHex("#696969") orelse unreachable,
            .dimgrey => comptime Color.fromHex("#696969") orelse unreachable,
            .dodgerblue => comptime Color.fromHex("#1e90ff") orelse unreachable,
            .firebrick => comptime Color.fromHex("#b22222") orelse unreachable,
            .floralwhite => comptime Color.fromHex("#fffaf0") orelse unreachable,
            .forestgreen => comptime Color.fromHex("#228b22") orelse unreachable,
            .gainsboro => comptime Color.fromHex("#dcdcdc") orelse unreachable,
            .ghostwhite => comptime Color.fromHex("#f8f8ff") orelse unreachable,
            .gold => comptime Color.fromHex("#ffd700") orelse unreachable,
            .goldenrod => comptime Color.fromHex("#daa520") orelse unreachable,
            .greenyellow => comptime Color.fromHex("#adff2f") orelse unreachable,
            .grey => comptime Color.fromHex("#808080") orelse unreachable,
            .honeydew => comptime Color.fromHex("#f0fff0") orelse unreachable,
            .hotpink => comptime Color.fromHex("#ff69b4") orelse unreachable,
            .indianred => comptime Color.fromHex("#cd5c5c") orelse unreachable,
            .indigo => comptime Color.fromHex("#4b0082") orelse unreachable,
            .ivory => comptime Color.fromHex("#fffff0") orelse unreachable,
            .khaki => comptime Color.fromHex("#f0e68c") orelse unreachable,
            .lavender => comptime Color.fromHex("#e6e6fa") orelse unreachable,
            .lavenderblush => comptime Color.fromHex("#fff0f5") orelse unreachable,
            .lawngreen => comptime Color.fromHex("#7cfc00") orelse unreachable,
            .lemonchiffon => comptime Color.fromHex("#fffacd") orelse unreachable,
            .lightblue => comptime Color.fromHex("#add8e6") orelse unreachable,
            .lightcoral => comptime Color.fromHex("#f08080") orelse unreachable,
            .lightcyan => comptime Color.fromHex("#e0ffff") orelse unreachable,
            .lightgoldenrodyellow => comptime Color.fromHex("#fafad2") orelse unreachable,
            .lightgray => comptime Color.fromHex("#d3d3d3") orelse unreachable,
            .lightgreen => comptime Color.fromHex("#90ee90") orelse unreachable,
            .lightgrey => comptime Color.fromHex("#d3d3d3") orelse unreachable,
            .lightpink => comptime Color.fromHex("#ffb6c1") orelse unreachable,
            .lightsalmon => comptime Color.fromHex("#ffa07a") orelse unreachable,
            .lightseagreen => comptime Color.fromHex("#20b2aa") orelse unreachable,
            .lightskyblue => comptime Color.fromHex("#87cefa") orelse unreachable,
            .lightslategray => comptime Color.fromHex("#778899") orelse unreachable,
            .lightslategrey => comptime Color.fromHex("#778899") orelse unreachable,
            .lightsteelblue => comptime Color.fromHex("#b0c4de") orelse unreachable,
            .lightyellow => comptime Color.fromHex("#ffffe0") orelse unreachable,
            .linen => comptime Color.fromHex("#faf0e6") orelse unreachable,
            .magenta => comptime Color.fromHex("#ff00ff") orelse unreachable,
            .mediumaquamarine => comptime Color.fromHex("#66cdaa") orelse unreachable,
            .mediumblue => comptime Color.fromHex("#0000cd") orelse unreachable,
            .mediumorchid => comptime Color.fromHex("#ba55d3") orelse unreachable,
            .mediumpurple => comptime Color.fromHex("#9370db") orelse unreachable,
            .mediumseagreen => comptime Color.fromHex("#3cb371") orelse unreachable,
            .mediumslateblue => comptime Color.fromHex("#7b68ee") orelse unreachable,
            .mediumspringgreen => comptime Color.fromHex("#00fa9a") orelse unreachable,
            .mediumturquoise => comptime Color.fromHex("#48d1cc") orelse unreachable,
            .mediumvioletred => comptime Color.fromHex("#c71585") orelse unreachable,
            .midnightblue => comptime Color.fromHex("#191970") orelse unreachable,
            .mintcream => comptime Color.fromHex("#f5fffa") orelse unreachable,
            .mistyrose => comptime Color.fromHex("#ffe4e1") orelse unreachable,
            .moccasin => comptime Color.fromHex("#ffe4b5") orelse unreachable,
            .navajowhite => comptime Color.fromHex("#ffdead") orelse unreachable,
            .oldlace => comptime Color.fromHex("#fdf5e6") orelse unreachable,
            .olivedrab => comptime Color.fromHex("#6b8e23") orelse unreachable,
            .orange => comptime Color.fromHex("#ffa500") orelse unreachable,
            .orangered => comptime Color.fromHex("#ff4500") orelse unreachable,
            .orchid => comptime Color.fromHex("#da70d6") orelse unreachable,
            .palegoldenrod => comptime Color.fromHex("#eee8aa") orelse unreachable,
            .palegreen => comptime Color.fromHex("#98fb98") orelse unreachable,
            .paleturquoise => comptime Color.fromHex("#afeeee") orelse unreachable,
            .palevioletred => comptime Color.fromHex("#db7093") orelse unreachable,
            .papayawhip => comptime Color.fromHex("#ffefd5") orelse unreachable,
            .peachpuff => comptime Color.fromHex("#ffdab9") orelse unreachable,
            .peru => comptime Color.fromHex("#cd853f") orelse unreachable,
            .pink => comptime Color.fromHex("#ffc0cb") orelse unreachable,
            .plum => comptime Color.fromHex("#dda0dd") orelse unreachable,
            .powderblue => comptime Color.fromHex("#b0e0e6") orelse unreachable,
            .rebeccapurple => comptime Color.fromHex("#663399") orelse unreachable,
            .rosybrown => comptime Color.fromHex("#bc8f8f") orelse unreachable,
            .royalblue => comptime Color.fromHex("#4169e1") orelse unreachable,
            .saddlebrown => comptime Color.fromHex("#8b4513") orelse unreachable,
            .salmon => comptime Color.fromHex("#fa8072") orelse unreachable,
            .sandybrown => comptime Color.fromHex("#f4a460") orelse unreachable,
            .seagreen => comptime Color.fromHex("#2e8b57") orelse unreachable,
            .seashell => comptime Color.fromHex("#fff5ee") orelse unreachable,
            .sienna => comptime Color.fromHex("#a0522d") orelse unreachable,
            .skyblue => comptime Color.fromHex("#87ceeb") orelse unreachable,
            .slateblue => comptime Color.fromHex("#6a5acd") orelse unreachable,
            .slategray => comptime Color.fromHex("#708090") orelse unreachable,
            .slategrey => comptime Color.fromHex("#708090") orelse unreachable,
            .snow => comptime Color.fromHex("#fffafa") orelse unreachable,
            .springgreen => comptime Color.fromHex("#00ff7f") orelse unreachable,
            .steelblue => comptime Color.fromHex("#4682b4") orelse unreachable,
            .tan => comptime Color.fromHex("#d2b48c") orelse unreachable,
            .thistle => comptime Color.fromHex("#d8bfd8") orelse unreachable,
            .tomato => comptime Color.fromHex("#ff6347") orelse unreachable,
            .transparent => comptime Color.fromHex("#00000000") orelse unreachable,
            .turquoise => comptime Color.fromHex("#40e0d0") orelse unreachable,
            .violet => comptime Color.fromHex("#ee82ee") orelse unreachable,
            .wheat => comptime Color.fromHex("#f5deb3") orelse unreachable,
            .whitesmoke => comptime Color.fromHex("#f5f5f5") orelse unreachable,
            .yellowgreen => comptime Color.fromHex("#9acd32") orelse unreachable,
        };
    }
};
pub fn parseRgb(src: []const u8, pos: usize) utils.ParseError!utils.Result(Color) {
    const start = utils.eatWhitespace(src, pos);
    var cursor = start;
    const fn_call = utils.consumeFnCall(src, cursor);
    if (fn_call.empty()) {
        return error.InvalidSyntax;
    }
    if (!fn_call.match("rgb(") and !fn_call.match("rgba(")) {
        return error.InvalidSyntax;
    }

    cursor = utils.eatWhitespace(src, fn_call.end);
    const r = try parsers.utils.parseNumber(src, cursor);
    if (r.empty()) {
        return error.InvalidSyntax;
    }

    cursor = utils.eatWhitespace(src, r.end);
    cursor = utils.consumeChar(src, ',', cursor) orelse return error.InvalidSyntax;
    cursor = utils.eatWhitespace(src, cursor);
    const g = try parsers.utils.parseNumber(src, cursor);
    if (g.empty()) {
        return error.InvalidSyntax;
    }
    cursor = utils.eatWhitespace(src, g.end);
    cursor = utils.consumeChar(src, ',', cursor) orelse return error.InvalidSyntax;
    cursor = utils.eatWhitespace(src, cursor);
    const b = try parsers.utils.parseNumber(src, cursor);
    if (b.empty()) {
        return error.InvalidSyntax;
    }
    cursor = utils.eatWhitespace(src, b.end);

    cursor = utils.consumeChar(src, ',', cursor) orelse {
        const end = utils.consumeChar(src, ')', cursor) orelse return error.InvalidSyntax;
        return .{
            .value = Color{
                .r = (std.fmt.parseFloat(f64, r.value) catch return error.InvalidSyntax) / 255,
                .g = (std.fmt.parseFloat(f64, g.value) catch return error.InvalidSyntax) / 255,
                .b = (std.fmt.parseFloat(f64, b.value) catch return error.InvalidSyntax) / 255,
                .a = 1.0,
            },
            .start = start,
            .end = end,
        };
    };
    cursor = utils.eatWhitespace(src, cursor);
    const a = try parsers.utils.parseNumber(src, cursor);
    cursor = utils.eatWhitespace(src, a.end);
    const end = utils.consumeChar(src, ')', cursor) orelse return error.InvalidSyntax;
    return .{
        .value = Color{
            .r = (std.fmt.parseFloat(f64, r.value) catch return error.InvalidSyntax) / 255,
            .g = (std.fmt.parseFloat(f64, g.value) catch return error.InvalidSyntax) / 255,
            .b = (std.fmt.parseFloat(f64, b.value) catch return error.InvalidSyntax) / 255,
            .a = (std.fmt.parseFloat(f64, a.value) catch return error.InvalidSyntax),
        },
        .start = start,
        .end = end,
    };
}
pub fn toOptional(comptime T: type, any: anytype) ?T {
    return any catch null;
}
pub fn parseHex(src: []const u8, pos: usize) !?utils.Result(Color) {
    const start = utils.eatWhitespace(src, pos);
    var end = start;
    if (src[end] != '#') {
        return null;
    }
    end += 1;
    while (end < src.len and std.ascii.isHex(src[end])) {
        end += 1;
    }
    const hex = src[start..end];
    const rgb = Color.fromHex(hex) orelse return error.InvalidSyntax;
    return .{ .value = rgb, .start = start, .end = end };
}
pub fn parse(src: []const u8, pos: usize) !utils.Result(Color) {
    if (toOptional(utils.Result(Color), parseRgb(src, pos))) |rgb| {
        return rgb;
    }
    if (try parseHex(src, pos)) |hex| {
        return hex;
    }
    if (utils.parseEnum(NamedColor, src, pos)) |named_color| {
        return .{
            .value = named_color.value.toRgb(),
            .start = named_color.start,
            .end = named_color.end,
        };
    }
    return error.InvalidSyntax;
}

test "parseColor" {
    const allocator = std.testing.allocator;
    const src = "#ffffff";
    const pos = 0;
    const color = try parse(allocator, src, pos);
    std.debug.print("color: {any} {s}\n", .{ color, src[color.start..color.end] });
    // try std.testing.expectEqual(color, Color{ .r = 1, .g = 1, .b = 1, .a = 1 });
}
