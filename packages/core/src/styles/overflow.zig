const std = @import("std");
const utils = @import("utils.zig");
pub const Overflow = enum {
    /// The automatic minimum size of this node as a flexbox/grid item should be based on the size of its content.
    /// Content that overflows this node *should* contribute to the scroll region of its parent.
    visible,
    /// The automatic minimum size of this node as a flexbox/grid item should be based on the size of its content.
    /// Content that overflows this node should *not* contribute to the scroll region of its parent.
    clip,
    /// The automatic minimum size of this node as a flexbox/grid item should be `0`.
    /// Content that overflows this node should *not* contribute to the scroll region of its parent.
    hidden,
    /// The automatic minimum size of this node as a flexbox/grid item should be `0`. Additionally, space should be reserved
    /// for a scrollbar. The amount of space reserved is controlled by the `scrollbar_width` property.
    /// Content that overflows this node should *not* contribute to the scroll region of its parent.
    scroll,
    pub const DEFAULT = Overflow.visible;

    /// Returns true for overflow modes that contain their contents (`Overflow::Hidden`, `Overflow::Scroll`, `Overflow::Auto`)
    /// or else false for overflow modes that allow their contains to spill (`Overflow::Visible`).
    pub fn isScrollContainer(self: Overflow) bool {
        return self == .scroll or self == .hidden;
    }

    /// Returns `Some(0.0)` if the overflow mode would cause the automatic minimum size of a Flexbox or CSS Grid item
    /// to be `0`. Else returns None.
    pub fn maybeIntoAutomaticMinSize(self: Overflow) ?f32 {
        if (self.isScrollContainer()) {
            return 0;
        }
        return null;
    }
};

pub fn parse(src: []const u8, pos: usize) !utils.Result(Overflow) {
    return utils.parseEnum(Overflow, src, pos) orelse error.InvalidSyntax;
}
