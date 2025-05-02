const std = @import("std");
const utils = @import("utils.zig");

/// Font style (normal, italic)
pub const FontStyle = enum {
    /// Regular/normal font style
    normal,

    /// Italic or oblique font style
    italic,

    /// Inherit from parent
    inherit,
};

/// Parse font style from a string
pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(FontStyle) {
    return utils.parseEnum(FontStyle, src, pos) orelse error.InvalidSyntax;
}

test "parse font style" {
    const normal_result = try parse("normal", 0);
    try std.testing.expectEqual(normal_result.value, .normal);

    const italic_result = try parse("italic", 0);
    try std.testing.expectEqual(italic_result.value, .italic);

    const inherit_result = try parse("inherit", 0);
    try std.testing.expectEqual(inherit_result.value, .inherit);
}
