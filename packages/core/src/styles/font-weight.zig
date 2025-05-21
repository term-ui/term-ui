const std = @import("std");
const utils = @import("utils.zig");
/// Font weight for bold/dim text
pub const FontWeight = enum {
    /// Normal weight (regular)
    normal,

    /// Bold text
    bold,

    /// Dimmed text (reduced intensity)
    dim,

    /// Inherit from parent
    inherit,
};

/// Parse font weight from a string
pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(FontWeight) {
    return utils.parseEnum(FontWeight, src, pos) orelse error.InvalidSyntax;
}


test "parse font weight" {
    const normal_result = try parse("normal", 0);
    try std.testing.expectEqual(normal_result.value, .normal);

    const bold_result = try parse("bold", 0);
    try std.testing.expectEqual(bold_result.value, .bold);

    const dim_result = try parse("dim", 0);
    try std.testing.expectEqual(dim_result.value, .dim);

    const inherit_result = try parse("inherit", 0);
    try std.testing.expectEqual(inherit_result.value, .inherit);
}
