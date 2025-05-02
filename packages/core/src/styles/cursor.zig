const std = @import("std");
const utils = @import("utils.zig");
const Point = @import("../layout/point.zig").Point;

const MemberType = @import("../layout/utils/comptime.zig").MemberType;
pub const Cursor = enum(u8) {
    alias = 0,

    cell = 1,

    copy = 2,

    crosshair = 3,

    default = 4,

    e_resize = 5,

    ew_resize = 6,

    grab = 7,

    grabbing = 8,

    help = 9,

    move = 10,

    n_resize = 11,

    ne_resize = 12,

    nesw_resize = 13,

    no_drop = 14,

    not_allowed = 15,

    ns_resize = 16,

    nw_resize = 17,

    nwse_resize = 18,

    pointer = 19,

    progress = 20,

    s_resize = 21,

    se_resize = 22,

    sw_resize = 23,

    text = 24,

    vertical_text = 25,

    w_resize = 26,

    wait = 27,

    zoom_in = 28,

    zoom_out = 29,
};

pub fn parse(src: []const u8, pos: usize) utils.ParseError!utils.Result(Cursor) {
    return utils.parseEnum(Cursor, src, pos) orelse error.InvalidSyntax;
}
