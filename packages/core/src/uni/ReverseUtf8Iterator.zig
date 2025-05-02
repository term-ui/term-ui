const std = @import("std");

bytes: []const u8,
i: usize,

const Self = @This();

pub fn init(bytes: []const u8) Self {
    return Self{
        .bytes = bytes,
        .i = bytes.len,
    };
}

pub fn next(self: *Self) ?[]const u8 {
    if (self.i == 0) {
        return null;
    }

    var iter = std.mem.reverseIterator(self.bytes[0..self.i]);

    var byte = iter.next().?;
    var len: usize = 1;
    self.i -= 1;
    while (len < 4 and isContByte(byte)) {
        byte = iter.next().?;
        len += 1;
        self.i -= 1;
    }

    return self.bytes[self.i..][0..len];
}

inline fn isContByte(code_point: u8) bool {
    return @as(i8, @bitCast(code_point)) < -64;
}
