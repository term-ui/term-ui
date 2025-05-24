const mod = @import("../mod.zig");
const LineBox = @import("./LineBox.zig");
const LineBoxFragment = @import("./LineBoxFragment.zig");
const std = @import("std");
const ArrayList = std.ArrayList;
const LineBreak = @import("../../../uni/LineBreak.zig");

lines: ArrayList(LineBox),
segmenter: LineBreak,
available_width: mod.constants.AvailableSpace,

const Self = @This();

pub fn addNewLine(self: *Self, available_width: f32) !void {
    const line = LineBox{
        .available_width = available_width,
        .fragments = ArrayList(LineBoxFragment).init(self.allocator),
    };

    try self.lines.append(line);
}

pub fn ensureLine(self: *Self, available_width: f32) !void {
    if (self.lines.items.len == 0) {
        try self.addNewLine(available_width);
    }
}

pub fn build(self: *Self) ArrayList(LineBox) {
    return self.lines;
}
