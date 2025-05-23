const std = @import("std");
const utils = @import("utils.zig");
// FIXME: add static position
pub const Position = enum {
    /// The offset is computed relative to the final position given by the layout algorithm.
    /// Offsets do not affect the position of any other items; they are effectively a correction factor applied at the end.
    relative,
    /// The offset is computed relative to this item's closest positioned ancestor, if any.
    /// Otherwise, it is placed relative to the origin.
    /// No space is created for the item in the page layout, and its size will not be altered.
    ///
    /// WARNING: to opt-out of layouting entirely, you must use [`Display::None`] instead on your [`Style`] object.
    absolute,

    pub const DEFAULT = Position.relative;
};

pub fn parse(src: []const u8, pos: usize) !utils.Result(Position) {
    return utils.parseEnum(Position, src, pos) orelse error.InvalidSyntax;
}
