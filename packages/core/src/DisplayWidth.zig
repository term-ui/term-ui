const c = @import("./unicode/c.zig").c;
const std = @import("std");

const EastAsianWidth = enum(u8) {
    Neutral = 0,
    Ambiguous = 1,
    Halfwidth = 2,
    Fullwidth = 3,
    Narrow = 4,
    Wide = 5,

    pub fn fromInt(v: anytype) !EastAsianWidth {
        return switch (v) {
            0 => .Neutral,
            1 => .Ambiguous,
            2 => .Halfwidth,
            3 => .Fullwidth,
            4 => .Narrow,
            5 => .Wide,
            else => error.InvalidEastAsianWidth,
        };
    }
    pub fn width(self: EastAsianWidth) !u8 {
        return switch (self) {
            .Neutral => 0,
            .Ambiguous => 2,
            .Halfwidth => 1,
            .Fullwidth => 2,
            .Narrow => 1,
            .Wide => 2,
        };
    }
};
pub fn getWidth(codepoint: u21) !EastAsianWidth {
    const provider = c.ICU4XDataProvider_create_compiled();
    errdefer c.ICU4XDataProvider_destroy(provider);

    const east_asian_width_data_result = c.ICU4XCodePointMapData8_load_east_asian_width(provider);

    if (east_asian_width_data_result.is_ok == false) {
        return error.FailedToLoadLineBreakData;
    }

    const east_asian_width = east_asian_width_data_result.unnamed_0.ok;
    errdefer c.ICU4XCodePointMapData8_destroy(east_asian_width);
    const width = c.ICU4XCodePointMapData8_get(east_asian_width, codepoint);
    // impl EastAsianWidth {
    //     pub const Neutral: EastAsianWidth = EastAsianWidth(0); //name="N"
    //     pub const Ambiguous: EastAsianWidth = EastAsianWidth(1); //name="A"
    //     pub const Halfwidth: EastAsianWidth = EastAsianWidth(2); //name="H"
    //     pub const Fullwidth: EastAsianWidth = EastAsianWidth(3); //name="F"
    //     pub const Narrow: EastAsianWidth = EastAsianWidth(4); //name="Na"
    //     pub const Wide: EastAsianWidth = EastAsianWidth(5); //name="W"
    // }
    // switch width {
    //     0 => return 0,
    //     1 => return 1,
    //     2 => return 2,
    //     3 => return 3,
    //     4 => return 4,
    //     5 => return 5,
    //     _ => return 0,
    // }
    return try EastAsianWidth.fromInt(width);
}

test "DisplayWidth" {
    // const provider = c.ICU4XDataProvider_create_compiled();
    // errdefer c.ICU4XDataProvider_destroy(provider);
    //
    // const east_asian_width_data_result = c.ICU4XCodePointMapData8_load_east_asian_width(provider);
    //
    // if (east_asian_width_data_result.is_ok == false) {
    //     return error.FailedToLoadLineBreakData;
    // }
    //
    // const east_asian_width = east_asian_width_data_result.unnamed_0.ok;
    // errdefer c.ICU4XCodePointMapData8_destroy(east_asian_width);
    // const width = c.ICU4XCodePointMapData8_get(east_asian_width, 'a');
    //
    const width = try getWidth('ｱ');

    std.debug.print("Width: {any}\n", .{width});
}
