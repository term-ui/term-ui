const std = @import("std");
const LineBreak = @import("LineBreak.zig");
const ReverseUtf8Iterator = @import("ReverseUtf8Iterator.zig");

pub const LineBreakStream = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayListUnmanaged(u8) = .{},
    iter: LineBreak = LineBreak.initAssumeValid(""),
    global_index: usize = 0,
    finished: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator }; // buffer and iter already zero-init
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn feed(self: *Self, bytes: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, bytes);
        self.iter.str = self.buffer.items;
    }

    pub fn finish(self: *Self) void {
        self.finished = true;
    }

    fn consume(self: *Self, count: usize) !void {
        self.global_index += count;
        try self.buffer.replaceRange(self.allocator, 0, count, &[_]u8{});
        self.iter.str = self.buffer.items;
        self.iter.i -= count;
    }

    pub fn next(self: *Self) !?LineBreak.Break {
        while (true) {
            const maybe = self.iter.next();
            if (maybe == null) return null;
            var brk = maybe.?;
            if (brk.mandatory and brk.i == self.iter.str.len and !self.finished) {
                // rewind to start of last codepoint and wait for more data
                var rev = ReverseUtf8Iterator.init(self.iter.str[0..brk.i]);
                const slice = rev.next().?;
                const start = brk.i - slice.len;
                self.iter.i = start;
                return null;
            }
            const index = self.global_index + brk.i;
            try self.consume(brk.i);
            return .{ .mandatory = brk.mandatory, .i = index };
        }
    }
};

test "LineBreakStream basic" {
    var stream = LineBreakStream.init(std.testing.allocator);
    defer stream.deinit();

    try stream.feed("a");
    try std.testing.expectEqual(@as(?LineBreak.Break, null), try stream.next());

    try stream.feed("\nb");
    var brk = (try stream.next()).?;
    try std.testing.expectEqual(@as(usize, 2), brk.i);
    try std.testing.expect(brk.mandatory);

    stream.finish();
    brk = (try stream.next()).?;
    try std.testing.expectEqual(@as(usize, 3), brk.i);
    try std.testing.expect(brk.mandatory);
    try std.testing.expectEqual(@as(?LineBreak.Break, null), try stream.next());
}

fn collectBreaks(alloc: std.mem.Allocator, text: []const u8) ![]LineBreak.Break {
    var iter = LineBreak.initAssumeValid(text);
    var arr = std.ArrayList(LineBreak.Break).init(alloc);
    while (iter.next()) |brk| {
        try arr.append(brk);
    }
    return arr.toOwnedSlice();
}

fn collectStreamBreaks(
    alloc: std.mem.Allocator,
    text: []const u8,
    chunk_size: usize,
) ![]LineBreak.Break {
    var stream = LineBreakStream.init(alloc);
    defer stream.deinit();
    var arr = std.ArrayList(LineBreak.Break).init(alloc);
    var i: usize = 0;
    while (i < text.len) {
        const end = @min(i + chunk_size, text.len);
        try stream.feed(text[i..end]);
        i = end;
        while (try stream.next()) |brk| {
            try arr.append(brk);
        }
    }
    stream.finish();
    while (try stream.next()) |brk| {
        try arr.append(brk);
    }
    return arr.toOwnedSlice();
}

test "LineBreakStream long sentence" {
    const text =
        "This is a longer sentence to validate the streaming line break iterator.";
    var baseline = try collectBreaks(std.testing.allocator, text);
    defer std.testing.allocator.free(baseline);
    var streamed = try collectStreamBreaks(std.testing.allocator, text, 5);
    defer std.testing.allocator.free(streamed);

    try std.testing.expectEqual(baseline.len, streamed.len);
    var i: usize = 0;
    while (i < baseline.len) : (i += 1) {
        try std.testing.expectEqual(baseline[i].mandatory, streamed[i].mandatory);
        try std.testing.expectEqual(baseline[i].i, streamed[i].i);
    }
}

test "LineBreakStream with emoji and asian" {
    const text = "Here is a smile 😊 and 日本語のテキストで改行をテストします.";
    var baseline = try collectBreaks(std.testing.allocator, text);
    defer std.testing.allocator.free(baseline);
    var streamed = try collectStreamBreaks(std.testing.allocator, text, 4);
    defer std.testing.allocator.free(streamed);

    try std.testing.expectEqual(baseline.len, streamed.len);
    var i: usize = 0;
    while (i < baseline.len) : (i += 1) {
        try std.testing.expectEqual(baseline[i].mandatory, streamed[i].mandatory);
        try std.testing.expectEqual(baseline[i].i, streamed[i].i);
    }
}
