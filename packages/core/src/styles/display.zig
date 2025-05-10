const std = @import("std");
const utils = @import("utils.zig");
const fmt = @import("../fmt.zig");
const DisplayOutside = enum {
    none,
    block,
    @"inline",
};

const DisplayInside = enum {
    flow,
    flow_root,
    flex,
};
pub const Display = struct {
    outside: DisplayOutside,
    inside: DisplayInside,
    pub const BLOCK: Display = .{
        .outside = .block,
        .inside = .flow_root,
    };

    pub const INLINE_BLOCK: Display = .{
        .outside = .@"inline",
        .inside = .flow_root,
    };

    pub const INLINE: Display = .{
        .outside = .@"inline",
        .inside = .flow,
    };

    pub const FLEX: Display = .{
        .outside = .block,
        .inside = .flex,
    };

    pub const INLINE_FLEX: Display = .{
        .outside = .@"inline",
        .inside = .flex,
    };

    pub const NONE: Display = .{
        .outside = .none,
        .inside = .flow_root,
    };
    pub fn isInlineFlow(self: Display) bool {
        return self.outside == .@"inline" and self.inside == .flow;
    }
    pub fn isFlowRoot(self: Display) bool {
        return self.outside == .@"inline" and self.inside == .flow_root;
    }
};

// syntax: [ <display-outside> || <display-inside> ] | <display-outside> | inline-block | flex
pub fn parse(src: []const u8, pos: usize) !utils.Result(Display) {
    const start = utils.eatWhitespace(src, pos);
    var cursor = start;
    const firstIdentifier = utils.consumeIdentifier(src, cursor);
    if (firstIdentifier.empty()) {
        return error.InvalidSyntax;
    }
    cursor = utils.eatWhitespace(src, firstIdentifier.end);
    const secondIdentifier = utils.consumeIdentifier(src, cursor);
    cursor = secondIdentifier.end;
    if (!utils.isEop(src, cursor)) return error.InvalidSyntax;
    if (!secondIdentifier.empty()) {
        return .{
            .value = Display{
                .outside = (utils.parseEnum(DisplayOutside, firstIdentifier.value, 0) orelse return error.InvalidSyntax).value,
                .inside = (utils.parseEnum(DisplayInside, secondIdentifier.value, 0) orelse return error.InvalidSyntax).value,
            },
            .start = pos,
            .end = cursor,
        };
    }
    if (std.mem.eql(u8, firstIdentifier.value, "inline-block")) {
        return .{ .value = Display.INLINE_BLOCK, .start = pos, .end = cursor };
    }
    if (std.mem.eql(u8, firstIdentifier.value, "flex")) {
        return .{ .value = Display.FLEX, .start = pos, .end = cursor };
    }
    if (std.mem.eql(u8, firstIdentifier.value, "none")) {
        return .{ .value = Display.NONE, .start = pos, .end = cursor };
    }
    if (std.mem.eql(u8, firstIdentifier.value, "inline-flex")) {
        return .{ .value = Display.INLINE_FLEX, .start = pos, .end = cursor };
    }
    const outside = utils.parseEnum(DisplayOutside, firstIdentifier.value, 0) orelse return error.InvalidSyntax;
    return .{
        .value = Display{
            .outside = outside.value,
            .inside = switch (outside.value) {
                .block => .flow_root,
                .@"inline" => .flow,
                .none => .flow_root,
            },
        },
        .start = pos,
        .end = cursor,
    };
}

test {
    const display = try parse("block", 0);
    try std.testing.expectEqual(display.value, Display{
        .outside = .block,
        .inside = .flow_root,
    });
    const display2 = try parse("inline-block", 0);
    try std.testing.expectEqual(display2.value, Display.INLINE_BLOCK);
    const display3 = try parse("flex", 0);
    try std.testing.expectEqual(display3.value, Display.FLEX);
    const display4 = try parse("none", 0);
    try std.testing.expectEqual(display4.value, Display.NONE);
    const display5 = try parse("inline-flex", 0);
    try std.testing.expectEqual(display5.value, Display.INLINE_FLEX);
    const display6 = try parse("inline flex", 0);

    try std.testing.expectEqual(display6.value, Display.INLINE_FLEX);
}
