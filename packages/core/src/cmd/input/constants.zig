const std = @import("std");
const Event = @import("manager.zig").Event;
const keys = @import("../keys.zig");
pub const KITTY_KEYS = [_][4]struct { Event.Named, u21, u8, bool }{
    .{ .key_iso_level3_shift, 57453, "u", true },
    .{ .key_iso_level5_shift, 57454, "u", true },
    .{ .key_iso_left_tab, 9, "u", false },

    .{ .key_backspace, 127, "u", false },
    .{ .key_tab, 9, "u", false },
    .{ .key_return, 13, "u", false },
    .{ .key_pause, 57362, "u", false },
    .{ .key_scroll_lock, 57359, "u", false },
    .{ .key_escape, 27, "u", false },
    .{ .key_home, 1, "H", false },
    .{ .key_left, 1, "D", false },
    .{ .key_up, 1, "A", false },
    .{ .key_right, 1, "C", false },
    .{ .key_down, 1, "B", false },
    .{ .key_prior, 5, "~", false },
    .{ .key_next, 6, "~", false },
    .{ .key_end, 1, "F", false },
    .{ .key_print, 57361, "u", false },
    .{ .key_insert, 2, "~", false },
    .{ .key_menu, 57363, "u", false },
    .{ .key_num_lock, 57360, "u", true },

    .{ .key_kp_enter, 57414, "u", false },
    .{ .key_kp_home, 57423, "u", false },
    .{ .key_kp_left, 57417, "u", false },
    .{ .key_kp_up, 57419, "u", false },
    .{ .key_kp_right, 57418, "u", false },
    .{ .key_kp_down, 57420, "u", false },
    .{ .key_kp_prior, 57421, "u", false },
    .{ .key_kp_next, 57422, "u", false },
    .{ .key_kp_end, 57424, "u", false },
    .{ .key_kp_begin, 1, "E", false },
    .{ .key_kp_insert, 57425, "u", false },
    .{ .key_kp_delete, 57426, "u", false },
    .{ .key_kp_multiply, 57411, "u", false },
    .{ .key_kp_add, 57413, "u", false },
    .{ .key_kp_separator, 57416, "u", false },
    .{ .key_kp_subtract, 57412, "u", false },
    .{ .key_kp_decimal, 57409, "u", false },
    .{ .key_kp_divide, 57410, "u", false },
    .{ .key_kp_0, 57399, "u", false },
    .{ .key_kp_1, 57400, "u", false },
    .{ .key_kp_2, 57401, "u", false },
    .{ .key_kp_3, 57402, "u", false },
    .{ .key_kp_4, 57403, "u", false },
    .{ .key_kp_5, 57404, "u", false },
    .{ .key_kp_6, 57405, "u", false },
    .{ .key_kp_7, 57406, "u", false },
    .{ .key_kp_8, 57407, "u", false },
    .{ .key_kp_9, 57408, "u", false },
    .{ .key_kp_equal, 57415, "u", false },

    .{ .key_f1, 1, "P", false },
    .{ .key_f2, 1, "Q", false },
    .{ .key_f3, 13, "~", false },
    .{ .key_f4, 1, "S", false },
    .{ .key_f5, 15, "~", false },
    .{ .key_f6, 17, "~", false },
    .{ .key_f7, 18, "~", false },
    .{ .key_f8, 19, "~", false },
    .{ .key_f9, 20, "~", false },
    .{ .key_f10, 21, "~", false },
    .{ .key_f11, 23, "~", false },
    .{ .key_f12, 24, "~", false },
    .{ .key_f13, 57376, "u", false },
    .{ .key_f14, 57377, "u", false },
    .{ .key_f15, 57378, "u", false },
    .{ .key_f16, 57379, "u", false },
    .{ .key_f17, 57380, "u", false },
    .{ .key_f18, 57381, "u", false },
    .{ .key_f19, 57382, "u", false },
    .{ .key_f20, 57383, "u", false },
    .{ .key_f21, 57384, "u", false },
    .{ .key_f22, 57385, "u", false },
    .{ .key_f23, 57386, "u", false },
    .{ .key_f24, 57387, "u", false },
    .{ .key_f25, 57388, "u", false },
    .{ .key_f26, 57389, "u", false },
    .{ .key_f27, 57390, "u", false },
    .{ .key_f28, 57391, "u", false },
    .{ .key_f29, 57392, "u", false },
    .{ .key_f30, 57393, "u", false },
    .{ .key_f31, 57394, "u", false },
    .{ .key_f32, 57395, "u", false },
    .{ .key_f33, 57396, "u", false },
    .{ .key_f34, 57397, "u", false },
    .{ .key_f35, 57398, "u", false },

    .{ .key_shift_l, 57441, "u", true },
    .{ .key_shift_r, 57447, "u", true },
    .{ .key_control_l, 57442, "u", true },
    .{ .key_control_r, 57448, "u", true },
    .{ .key_caps_lock, 57358, "u", true },
    .{ .key_meta_l, 57446, "u", true },
    .{ .key_meta_r, 57452, "u", true },
    .{ .key_alt_l, 57443, "u", true },
    .{ .key_alt_r, 57449, "u", true },
    .{ .key_super_l, 57444, "u", true },
    .{ .key_super_r, 57450, "u", true },
    .{ .key_hyper_l, 57445, "u", true },
    .{ .key_hyper_r, 57451, "u", true },

    .{ .key_delete, 3, "~", false },

    .{ .key_xf86_audio_lower_volume, 57438, "u", false },
    .{ .key_xf86_audio_mute, 57440, "u", false },
    .{ .key_xf86_audio_raise_volume, 57439, "u", false },
    .{ .key_xf86_audio_play, 57428, "u", false },
    .{ .key_xf86_audio_stop, 57432, "u", false },
    .{ .key_xf86_audio_prev, 57436, "u", false },
    .{ .key_xf86_audio_next, 57435, "u", false },
    .{ .key_xf86_audio_record, 57437, "u", false },
    .{ .key_xf86_audio_pause, 57429, "u", false },
    .{ .key_xf86_audio_rewind, 57434, "u", false },
    .{ .key_xf86_audio_forward, 57433, "u", false },
    .{ .key_xf86_audio_play_pause, 57430, "u", false },
    .{ .key_xf86_audio_reverse, 57431, "u", false },
};

pub fn getKeyNameFromNumber(key_number: u21) ?keys.Key {
    return switch (key_number) {
        57344 => .escape,
        57345 => .enter,
        57346 => .tab,
        57347 => .backspace,
        57348 => .insert,
        57349 => .delete,
        57350 => .left,
        57351 => .right,
        57352 => .up,
        57353 => .down,
        57354 => .page_up,
        57355 => .page_down,
        57356 => .home,
        57357 => .end,
        57358 => .caps_lock,
        57359 => .scroll_lock,
        57360 => .num_lock,
        57361 => .print_screen,
        57362 => .pause,
        // 57363 => .menu,
        57364 => .f1,
        57365 => .f2,
        57366 => .f3,
        57367 => .f4,
        57368 => .f5,
        57369 => .f6,
        57370 => .f7,
        57371 => .f8,
        57372 => .f9,
        57373 => .f10,
        57374 => .f11,
        57375 => .f12,
        57376 => .f13,
        57377 => .f14,
        57378 => .f15,
        57379 => .f16,
        57380 => .f17,
        57381 => .f18,
        57382 => .f19,
        57383 => .f20,
        57384 => .f21,
        57385 => .f22,
        57386 => .f23,
        57387 => .f24,
        57388 => .f25,
        // 57389 => .key_f26,
        // 57390 => .key_f27,
        // 57391 => .key_f28,
        // 57392 => .key_f29,
        // 57393 => .key_f30,
        // 57394 => .key_f31,
        // 57395 => .key_f32,
        // 57396 => .key_f33,
        // 57397 => .key_f34,
        // 57398 => .key_f35,
        57399 => .kp_0,
        57400 => .kp_1,
        57401 => .kp_2,
        57402 => .kp_3,
        57403 => .kp_4,
        57404 => .kp_5,
        57405 => .kp_6,
        57406 => .kp_7,
        57407 => .kp_8,
        57408 => .kp_9,
        57409 => .kp_decimal,
        57410 => .kp_divide,
        57411 => .kp_multiply,
        57412 => .kp_subtract,
        57413 => .kp_add,
        57414 => .kp_enter,
        57415 => .kp_equal,
        57416 => .kp_separator,
        57417 => .kp_left,
        57418 => .kp_right,
        57419 => .kp_up,
        57420 => .kp_down,
        57421 => .kp_page_up,
        57422 => .kp_page_down,
        57423 => .kp_home,
        57424 => .kp_end,
        57425 => .kp_insert,
        57426 => .kp_delete,
        57427 => .kp_begin,
        // 57428 => .media_play,
        // 57429 => .media_pause,
        // 57430 => .media_play_pause,
        // 57431 => .media_reverse,
        // 57432 => .media_stop,
        // 57433 => .media_fast_forward,
        // 57434 => .media_rewind,
        // 57435 => .media_track_next,
        // 57436 => .media_track_previous,
        // 57437 => .media_record,
        // 57438 => .lower_volume,
        // 57439 => .raise_volume,
        // 57440 => .mute_volume,
        57441 => .left_shift,
        57442 => .left_control,
        57443 => .left_alt,
        57444 => .left_super,
        // 57445 => .left_hyper,
        // 57446 => .left_meta,
        57447 => .right_shift,
        57448 => .right_control,
        57449 => .right_alt,
        57450 => .right_super,
        // 57451 => .right_hyper,
        // 57452 => .right_meta,
        // 57453 => .iso_level3_shift,
        // 57454 => .iso_level5_shift,
        else => null,
    };
}
const key_map = [_]struct { keys.Key, u21 }{
    .{ .a, 'a' },
    .{ .b, 'b' },
    .{ .c, 'c' },
    .{ .d, 'd' },
    .{ .e, 'e' },
    .{ .f, 'f' },
    .{ .g, 'g' },
    .{ .h, 'h' },
    .{ .i, 'i' },
    .{ .j, 'j' },
    .{ .k, 'k' },
    .{ .l, 'l' },
    .{ .m, 'm' },
    .{ .n, 'n' },
    .{ .o, 'o' },
    .{ .p, 'p' },
    .{ .q, 'q' },
    .{ .r, 'r' },
    .{ .s, 's' },
    .{ .t, 't' },
    .{ .u, 'u' },
    .{ .v, 'v' },
    .{ .w, 'w' },
    .{ .x, 'x' },
    .{ .y, 'y' },
    .{ .z, 'z' },
    .{ .@"0", '0' },
    .{ .@"1", '1' },
    .{ .@"2", '2' },
    .{ .@"3", '3' },
    .{ .@"4", '4' },
    .{ .@"5", '5' },
    .{ .@"6", '6' },
    .{ .@"7", '7' },
    .{ .@"8", '8' },
    .{ .@"9", '9' },
    .{ .semicolon, ';' },
    .{ .comma, ',' },
    .{ .period, '.' },
    .{ .slash, '/' },
    .{ .minus, '-' },
    .{ .plus, '+' },
    .{ .equal, '=' },
    .{ .left_bracket, '[' },
    .{ .right_bracket, ']' },
    .{ .backslash, '\\' },
    .{ .grave_accent, '`' },
    .{ .apostrophe, '\'' },
    // .quote => '"',

    .{ .escape, 57344 },
    .{ .enter, 57345 },
    .{ .tab, 57346 },
    .{ .backspace, 57347 },
    .{ .insert, 57348 },
    .{ .delete, 57349 },
    .{ .left, 57350 },
    .{ .right, 57351 },
    .{ .up, 57352 },
    .{ .down, 57353 },
    .{ .page_up, 57354 },
    .{ .page_down, 57355 },
    .{ .home, 57356 },
    .{ .end, 57357 },
    .{ .caps_lock, 57358 },
    .{ .scroll_lock, 57359 },
    .{ .num_lock, 57360 },
    .{ .print_screen, 57361 },
    .{ .pause, 57362 },
    // .menu => 57363,
    .{ .f1, 57364 },
    .{ .f2, 57365 },
    .{ .f3, 57366 },
    .{ .f4, 57367 },
    .{ .f5, 57368 },
    .{ .f6, 57369 },
    .{ .f7, 57370 },
    .{ .f8, 57371 },
    .{ .f9, 57372 },
    .{ .f10, 57373 },
    .{ .f11, 57374 },
    .{ .f12, 57375 },
    .{ .f13, 57376 },
    .{ .f14, 57377 },
    .{ .f15, 57378 },
    .{ .f16, 57379 },
    .{ .f17, 57380 },
    .{ .f18, 57381 },
    .{ .f19, 57382 },
    .{ .f20, 57383 },
    .{ .f21, 57384 },
    .{ .f22, 57385 },
    .{ .f23, 57386 },
    .{ .f24, 57387 },
    .{ .f25, 57388 },
    // .f26 => 57389,
    // .f27 => 57390,
    // .f28 => 57391,
    // .f29 => 57392,
    // .f30 => 57393,
    // .f31 => 57394,
    // .f32 => 57395,
    // .f33 => 57396,
    // .f34 => 57397,
    // .f35 => 57398,
    .{ .kp_0, 57399 },
    .{ .kp_1, 57400 },
    .{ .kp_2, 57401 },
    .{ .kp_3, 57402 },
    .{ .kp_4, 57403 },
    .{ .kp_5, 57404 },
    .{ .kp_6, 57405 },
    .{ .kp_7, 57406 },
    .{ .kp_8, 57407 },
    .{ .kp_9, 57408 },
    .{ .kp_decimal, 57409 },
    .{ .kp_divide, 57410 },
    .{ .kp_multiply, 57411 },
    .{ .kp_subtract, 57412 },
    .{ .kp_add, 57413 },
    .{ .kp_enter, 57414 },
    .{ .kp_equal, 57415 },
    .{ .kp_separator, 57416 },
    .{ .kp_left, 57417 },
    .{ .kp_right, 57418 },
    .{ .kp_up, 57419 },
    .{ .kp_down, 57420 },
    .{ .kp_page_up, 57421 },
    .{ .kp_page_down, 57422 },
    .{ .kp_home, 57423 },
    .{ .kp_end, 57424 },
    .{ .kp_insert, 57425 },
    .{ .kp_delete, 57426 },
    .{ .kp_begin, 57427 },
    // .media_play => 57428,
    // .media_pause => 57429,
    // .media_play_pause => 57430,
    // .media_reverse => 57431,
    // .media_stop => 57432,
    // .media_fast_forward => 57433,
    // .media_rewind => 57434,
    // .media_track_next => 57435,
    // .media_track_previous => 57436,
    // .media_record => 57437,
    // .lower_volume => 57438,
    // .raise_volume => 57439,
    // .mute_volume => 57440,
    .{ .left_shift, 57441 },
    .{ .left_control, 57442 },
    .{ .left_alt, 57443 },
    .{ .left_super, 57444 },
    // .left_hyper => 57445,
    // .left_meta => 57446,
    .{ .right_shift, 57447 },
    .{ .right_control, 57448 },
    .{ .right_alt, 57449 },
    .{ .right_super, 57450 },
    // .right_hyper => 57451,
    // .right_meta => 57452,
    // .iso_level3_shift => 57453,
    // .iso_level5_shift => 57454,

    .{ .space, ' ' },
};

pub fn getNumberFromKeyName(name: keys.Key) u21 {
    switch (name) {
        inline else => |key| {
            return comptime result: {
                @setEvalBranchQuota(100_000);
                for (key_map) |entry| {
                    if (entry[0] == key) {
                        break :result entry[1];
                    }
                }
                unreachable;
            };
        },
    }
}

// var csi_number_to_functional_number_map = map[int]int{2: 57348, 3: 57349, 5: 57354, 6: 57355, 7: 57356, 8: 57357, 9: 57346, 11: 57364, 12: 57365, 13: 57345, 14: 57367, 15: 57368, 17: 57369, 18: 57370, 19: 57371, 20: 57372, 21: 57373, 23: 57374, 24: 57375, 27: 57344, 127: 57347}

pub fn getFunctionalNumberFromCsiNumber(key_number: u21) u21 {
    return switch (key_number) {
        2 => 57348,
        3 => 57349,
        5 => 57354,
        6 => 57355,
        7 => 57356,
        8 => 57357,
        9 => 57346,
        11 => 57364,
        12 => 57365,
        13 => 57345,
        14 => 57367,
        15 => 57368,
        17 => 57369,
        18 => 57370,
        19 => 57371,
        20 => 57372,
        21 => 57373,
        23 => 57374,
        24 => 57375,
        27 => 57344,
        127 => 57347,
        else => key_number,
    };
}
const unshift_delta = 'a' - 'A';

pub fn getUnshifted(codepoint: u21) u21 {
    if (codepoint >= 'A' and codepoint <= 'Z') {
        return codepoint + unshift_delta;
    }
    return codepoint;
}
