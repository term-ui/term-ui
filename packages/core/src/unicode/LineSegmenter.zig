const c = @import("./c.zig").c;
const logger = std.log.scoped(.line_segmenter);
provider: *c.struct_ICU4XDataProvider,
segmenter: *c.struct_ICU4XLineSegmenter,
// iterator: *c.struct_ICU4XLineBreakIteratorUtf8,
line_break_data: *c.struct_ICU4XCodePointMapData8,
// str: []const u8,

const LineSegmenter = @This();

// var line_segmenter: ?LineSegmenter = null;
pub fn new() !LineSegmenter {
    const provider = c.ICU4XDataProvider_create_compiled() orelse return error.FailedToCreateDataProvider;
    errdefer c.ICU4XDataProvider_destroy(provider);

    const segmenter_result = c.ICU4XLineSegmenter_create_auto(provider);
    if (segmenter_result.is_ok == false) {
        return error.FailedToCreateLineSegmenter;
    }

    const segmenter = segmenter_result.unnamed_0.ok orelse return error.FailedToCreateLineSegmenter;
    errdefer c.ICU4XLineSegmenter_destroy(segmenter);

    const line_break_data_result = c.ICU4XCodePointMapData8_load_line_break(provider);
    if (line_break_data_result.is_ok == false) {
        return error.FailedToLoadLineBreakData;
    }

    const line_break_data = line_break_data_result.unnamed_0.ok orelse return error.FailedToLoadLineBreakData;
    errdefer c.ICU4XCodePointMapData8_destroy(line_break_data);

    logger.info("new LineSegmenter\n", .{});
    return .{
        .provider = provider,
        .segmenter = segmenter,
        .line_break_data = line_break_data,
    };
}
pub fn deinit(self: *LineSegmenter) void {
    c.ICU4XLineSegmenter_destroy(self.segmenter);
    c.ICU4XDataProvider_destroy(self.provider);
    c.ICU4XCodePointMapData8_destroy(self.line_break_data);
}

pub fn segmentString(self: *LineSegmenter, str: []const u8) !SegmentIterator {
    return SegmentIterator.new(self, str);
}
pub const Segment = struct {
    index: usize,
    break_type: BreakType,
    text: []const u8,
};

pub const SegmentIterator = struct {
    segmenter: *LineSegmenter,
    iterator: *c.struct_ICU4XLineBreakIteratorUtf8,
    str: []const u8,

    // eof: bool = false,
    cached: ?Segment = null,
    index: usize = 0,

    pub fn new(segmenter: *LineSegmenter, str: []const u8) !SegmentIterator {
        const iterator = c.ICU4XLineSegmenter_segment_utf8(segmenter.segmenter, str.ptr, str.len) orelse return error.FailedToSegmentUtf8String;
        // skip first because it is always 0, and not actually a break
        _ = c.ICU4XLineBreakIteratorUtf8_next(iterator);
        return .{ .segmenter = segmenter, .iterator = iterator, .str = str };
    }
    pub fn peek(self: *SegmentIterator) ?Segment {
        const next_break = self.next();
        self.cached = next_break;

        return next_break;
    }
    pub fn next(self: *SegmentIterator) ?Segment {
        if (self.cached) |cached| {
            self.cached = null;
            return cached;
        }
        const break_position = c.ICU4XLineBreakIteratorUtf8_next(self.iterator);
        if (break_position == -1) {
            return null;
        }
        const position: usize = @intCast(break_position);
        const text = self.str[self.index..position];
        self.index = position;
        return .{ .index = position, .break_type = self.getBreakType(position), .text = text };
    }

    pub fn getBreakType(self: *SegmentIterator, position: usize) BreakType {
        if (self.str.len == position) {
            return .Mandatory;
        }
        const break_property = c.ICU4XCodePointMapData8_get(self.segmenter.line_break_data, self.str[position - 1]);
        switch (break_property) {
            // https://github.com/unicode-org/icu4x/blob/4eeb7b7ab2a148c6ff37918a5a246af3759d4fd1/components/properties/src/props.rs#L1792
            6, // BK
            10, // CR
            17, // LF
            29, // NL
            => return .Mandatory, // LF
            else => return .Allowed,
        }
    }

    pub fn deinit(self: *SegmentIterator) void {
        c.ICU4XLineBreakIteratorUtf8_destroy(self.iterator);
    }
};
pub const BreakType = enum {
    Mandatory,
    Allowed,
    NotAllowed,
};
pub fn next(self: *LineSegmenter) ?struct { usize, BreakType } {
    const break_position = c.ICU4XLineBreakIteratorUtf8_next(self.iterator);
    if (break_position == -1) {
        return null;
    }
    const position: usize = @intCast(break_position);
    return .{ position, self.getBreakType(position) };
}

const std = @import("std");
const expectEqual = std.testing.expectEqual;

// test "LineSegmenter" {
//     var segmenter = try LineSegmenter.new();
//     const str = "Hello, world!";
//     var iter = try segmenter.segmentString(str);
//     defer iter.deinit();
//     defer segmenter.deinit();

//     try expectEqual(iter.next(), .{ 7, .Allowed });
//     try expectEqual(iter.next(), .{ 13, .Mandatory });
// }

// test "With explicit breaks" {
//     var segmenter = try LineSegmenter.new();
//     var iter = try segmenter.segmentString("Summary\r\nThis annex…");
//     defer iter.deinit();
//     defer segmenter.deinit();

//     try expectEqual(iter.next(), .{ 9, .Mandatory });
//     try expectEqual(iter.next(), .{ 14, .Allowed });
//     try expectEqual(iter.next(), .{ 22, .Mandatory });
// }
