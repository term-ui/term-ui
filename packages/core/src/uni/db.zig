const std = @import("std");
const lookups = @import("lookups.zig");
pub const EastAsianWidth = lookups.EastAsianWidth;
pub const LineBreak = lookups.LineBreak;
pub const GeneralCategory = lookups.GeneralCategory;

pub fn getHandle(comptime T: type) usize {
    inline for (std.meta.fields(lookups.Columns), 0..) |field, index| {
        if (field.type == T) {
            return index;
        }
    }
    unreachable;
}

pub fn getValue(comptime T: type, key: usize) T {
    const handle = comptime getHandle(T);
    const index: usize = lookups.index1[key >> lookups.shift];
    const ivalue: usize = lookups.index2[(index << lookups.shift) + (key & ((1 << lookups.shift) - 1))];
    return lookups.values[ivalue][handle];
}
pub fn getBoolValue(comptime column: usize, key: usize) bool {
    const index: usize = lookups.index1[key >> lookups.shift];
    const ivalue: usize = lookups.index2[(index << lookups.shift) + (key & ((1 << lookups.shift) - 1))];
    return lookups.values[ivalue][column];
}

test "getValue" {
    const value = getValue(lookups.EastAsianWidth, '\u{3400}');
    std.debug.print("value: {?}\n", .{value});
    std.debug.print("value: {?}\n", .{getValue(lookups.LineBreak, '0')});
    std.debug.print("index: {?}\n", .{getBoolValue(lookups.EmojiIndex, '\u{231A}')});
}
