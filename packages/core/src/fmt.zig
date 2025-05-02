const std = @import("std");

const io = std.io;
const mem = std.mem;
const IndentWriter = struct {
    // unbuffered_writer: WriterType,
    // buf: [buffer_size]u8 = undefined,
    // end: usize = 0,
    depth: usize = 0,
    indent_string: []const u8 = "  ",
    inner_writer: std.io.AnyWriter,
    is_new_line: bool = true,
    pub const Error = io.AnyWriter.Error;
    pub const Writer = io.Writer(*Self, Error, write);

    const Self = @This();

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn write(self: *Self, bytes: []const u8) Error!usize {
        for (bytes) |byte| {
            if (byte == '}' or byte == ']' or byte == ')') {
                self.is_new_line = true;
                self.depth -= 1;
            }
            if (byte == ',') {
                self.is_new_line = true;
                try self.inner_writer.writeByte(byte);
                continue;
            }
            if (self.is_new_line and byte == ' ') {
                continue;
            }
            if (self.is_new_line) {
                try self.inner_writer.writeByte('\n');
                try self.inner_writer.writeBytesNTimes(self.indent_string, self.depth);
                self.is_new_line = false;
            }
            try self.inner_writer.writeByte(byte);

            if (byte == '{' or byte == '[' or byte == '(') {
                self.is_new_line = true;
                self.depth += 1;
            }
        }
        return bytes.len;
    }
};

pub fn indentFormat(
    writer: std.io.AnyWriter,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    var indented_writer = IndentWriter{ .inner_writer = writer };
    try std.fmt.format(indented_writer.writer(), fmt, args);
}
pub const debug = struct {
    pub fn print(comptime fmt: []const u8, args: anytype) void {
        indentFormat(std.io.getStdErr().writer().any(), fmt, args) catch unreachable;
    }
};
