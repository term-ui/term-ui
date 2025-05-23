const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
// Generic CSS alignment code that is shared between both the Flexbox and CSS Grid algorithms.
// const AlignContent = @import("../../tree/Style.zig").AlignContent;
/// Generic alignment function that is used:
///   - For both align-content and justify-content alignment
///   - For both the Flexbox and CSS Grid algorithms
/// CSS Grid does not apply gaps as part of alignment, so the gap parameter should
/// always be set to zero for CSS Grid.
pub fn computeAlignmentOffset(
    free_space: f32,
    num_items: usize,
    gap: f32,
    alignment_mode: css_types.AlignContent,
    layout_is_flex_reversed: bool,
    is_first: bool,
) f32 {
    const num_items_: f32 = @floatFromInt(num_items);
    if (is_first) {
        switch (alignment_mode) {
            .start => return 0.0,
            .flex_start => if (layout_is_flex_reversed) {
                return free_space;
            } else {
                return 0.0;
            },
            .end => return free_space,
            .flex_end => if (layout_is_flex_reversed) {
                return 0.0;
            } else {
                return free_space;
            },
            .center => return free_space / 2.0,
            .stretch => return 0.0,
            .space_between => return 0.0,
            .space_around => if (free_space >= 0.0) {
                return (free_space / num_items_) / 2.0;
            } else {
                return free_space / 2.0;
            },

            .space_evenly => if (free_space >= 0.0) {
                return free_space / (num_items_ + 1);
            } else {
                return free_space / 2.0;
            },
        }
    } else {
        const free_space_ = @max(free_space, 0.0);
        switch (alignment_mode) {
            .start => return gap,
            .flex_start => return gap,
            .end => return gap,
            .flex_end => return gap,
            .center => return gap,
            .stretch => return gap,
            .space_between => return gap + free_space_ / (num_items_ - 1),
            .space_around => return gap + free_space_ / num_items_,
            .space_evenly => return gap + free_space_ / (num_items_ + 1),
        }
    }
}
