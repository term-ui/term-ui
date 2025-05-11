const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;
const db = @import("db.zig");
const lookups = @import("lookups.zig");

/// `Grapheme` represents a Unicode grapheme cluster by its length and offset in the source bytes.
pub const Grapheme = struct {
    len: u8,
    offset: u32,

    /// `bytes` returns the slice of bytes that correspond to
    /// this grapheme cluster in `src`.
    pub fn bytes(self: Grapheme, src: []const u8) []const u8 {
        return src[self.offset..][0..self.len];
    }
};
const Codepoint = struct {
    len: u8,
    offset: u32,
    code: u21,

    pub fn init(offset: u32, len: u8, src: []const u8) !Codepoint {
        return Codepoint{ .offset = offset, .len = len, .code = try unicode.utf8Decode(src[offset .. offset + len]) };
    }
    pub fn bytes(self: Codepoint, src: []const u8) []const u8 {
        return src[self.offset..][0..self.len];
    }
};
pub const Iterator = struct {
    buf: [2]?Codepoint = .{ null, null },
    cp_iter: unicode.Utf8Iterator,

    const Self = @This();

    /// Assumes `src` is valid UTF-8.
    pub fn init(str: []const u8) Self {
        var self = Self{ .cp_iter = .{ .bytes = str, .i = 0 } };
        self.advance();
        return self;
    }

    fn advance(self: *Self) void {
        self.buf[0] = self.buf[1];
        const i = self.cp_iter.i;
        self.buf[1] = if (self.cp_iter.nextCodepointSlice()) |slice| Codepoint.init(@intCast(i), @intCast(slice.len), self.cp_iter.bytes) catch unreachable else null;
    }

    pub fn next(self: *Self) ?Grapheme {
        self.advance();

        // If no more
        if (self.buf[0] == null) return null;
        // If last one
        if (self.buf[1] == null) return Grapheme{ .len = self.buf[0].?.len, .offset = self.buf[0].?.offset };
        // If ASCII
        if (self.buf[0].?.code != '\r' and self.buf[0].?.code < 128 and self.buf[1].?.code < 128) {
            return Grapheme{ .len = self.buf[0].?.len, .offset = self.buf[0].?.offset };
        }

        const gc_start = self.buf[0].?.offset;
        var gc_len: u8 = self.buf[0].?.len;
        var state = State{};

        if (graphemeBreak(
            self.buf[0].?.code,
            self.buf[1].?.code,
            &state,
        )) return Grapheme{ .len = gc_len, .offset = gc_start };

        while (true) {
            self.advance();
            if (self.buf[0] == null) break;

            gc_len += self.buf[0].?.len;

            if (graphemeBreak(
                self.buf[0].?.code,
                if (self.buf[1]) |ncp| ncp.code else 0,
                &state,
            )) break;
        }

        return Grapheme{ .len = gc_len, .offset = gc_start };
    }

    pub fn peek(self: *Self) ?Grapheme {
        const saved_cp_iter = self.cp_iter;
        const s0 = self.buf[0];
        const s1 = self.buf[1];

        self.advance();

        // If no more
        if (self.buf[0] == null) {
            self.cp_iter = saved_cp_iter;
            self.buf[0] = s0;
            self.buf[1] = s1;
            return null;
        }
        // If last one
        if (self.buf[1] == null) {
            const len = self.buf[0].?.len;
            const offset = self.buf[0].?.offset;
            self.cp_iter = saved_cp_iter;
            self.buf[0] = s0;
            self.buf[1] = s1;
            return Grapheme{ .len = len, .offset = offset };
        }
        // If ASCII
        if (self.buf[0].?.code != '\r' and self.buf[0].?.code < 128 and self.buf[1].?.code < 128) {
            const len = self.buf[0].?.len;
            const offset = self.buf[0].?.offset;
            self.cp_iter = saved_cp_iter;
            self.buf[0] = s0;
            self.buf[1] = s1;
            return Grapheme{ .len = len, .offset = offset };
        }

        const gc_start = self.buf[0].?.offset;
        var gc_len: u8 = self.buf[0].?.len;
        var state = State{};

        if (graphemeBreak(
            self.buf[0].?.code,
            self.buf[1].?.code,
            self.data,
            &state,
        )) {
            self.cp_iter = saved_cp_iter;
            self.buf[0] = s0;
            self.buf[1] = s1;
            return Grapheme{ .len = gc_len, .offset = gc_start };
        }

        while (true) {
            self.advance();
            if (self.buf[0] == null) break;

            gc_len += self.buf[0].?.len;

            if (graphemeBreak(
                self.buf[0].?.code,
                if (self.buf[1]) |ncp| ncp.code else 0,
                self.data,
                &state,
            )) break;
        }
        self.cp_iter = saved_cp_iter;
        self.buf[0] = s0;
        self.buf[1] = s1;

        return Grapheme{ .len = gc_len, .offset = gc_start };
    }
};

// Predicates
fn isBreaker(cp: u21) bool {
    // Extract relevant properties.
    const cp_gbp_prop = db.getValue(db.GraphemeBreak, cp);
    return cp == '\x0d' or cp == '\x0a' or cp_gbp_prop == .Control;
}

// Grapheme break state.
pub const State = struct {
    bits: u3 = 0,

    // Extended Pictographic (emoji)
    fn hasXpic(self: State) bool {
        return self.bits & 1 == 1;
    }
    fn setXpic(self: *State) void {
        self.bits |= 1;
    }
    fn unsetXpic(self: *State) void {
        self.bits ^= 1;
    }

    // Regional Indicatior (flags)
    fn hasRegional(self: State) bool {
        return self.bits & 2 == 2;
    }
    fn setRegional(self: *State) void {
        self.bits |= 2;
    }
    fn unsetRegional(self: *State) void {
        self.bits ^= 2;
    }

    // Indic Conjunct
    fn hasIndic(self: State) bool {
        return self.bits & 4 == 4;
    }
    fn setIndic(self: *State) void {
        self.bits |= 4;
    }
    fn unsetIndic(self: *State) void {
        self.bits ^= 4;
    }
};

/// `graphemeBreak` returns true only if a grapheme break point is required
/// between `cp1` and `cp2`. `state` should start out as 0. If calling
/// iteratively over a sequence of code points, this function must be called
/// IN ORDER on ALL potential breaks in a string.
/// Modeled after the API of utf8proc's `utf8proc_grapheme_break_stateful`.
/// https://github.com/JuliaStrings/utf8proc/blob/2bbb1ba932f727aad1fab14fafdbc89ff9dc4604/utf8proc.h#L599-L617
pub fn graphemeBreak(
    cp1: u21,
    cp2: u21,
    state: *State,
) bool {
    // Extract relevant properties.
    const cp1_gbp_prop = db.getGraphemeBreak(cp1);
    const cp1_indic_prop = db.getCoreProperty(cp1);
    const cp1_is_emoji = db.isEmoji(cp1);

    const cp2_gbp_prop = db.getGraphemeBreak(cp2);
    const cp2_indic_prop = db.getCoreProperty(cp2);
    const cp2_is_emoji = db.isEmoji(cp2);

    // GB11: Emoji Extend* ZWJ x Emoji
    if (!state.hasXpic() and cp1_is_emoji) state.setXpic();
    // GB9c: Indic Conjunct Break
    if (!state.hasIndic() and cp1_indic_prop == .InCB_Consonant) state.setIndic();

    // GB3: CR x LF
    if (cp1 == '\r' and cp2 == '\n') return false;

    // GB4: Control
    if (isBreaker(cp1)) return true;

    // GB11: Emoji Extend* ZWJ x Emoji
    if (state.hasXpic() and
        cp1_gbp_prop == .ZWJ and
        cp2_is_emoji)
    {
        state.unsetXpic();
        return false;
    }

    // GB9b: x (Extend | ZWJ)
    if (cp2_gbp_prop == .Extend or cp2_gbp_prop == .ZWJ) return false;

    // GB9a: x Spacing
    if (cp2_gbp_prop == .SpacingMark) return false;

    // GB9b: Prepend x
    if (cp1_gbp_prop == .Prepend and !isBreaker(cp2)) return false;

    // GB12, GB13: RI x RI
    if (cp1_gbp_prop == .Regional_Indicator and cp2_gbp_prop == .Regional_Indicator) {
        if (state.hasRegional()) {
            state.unsetRegional();
            return true;
        } else {
            state.setRegional();
            return false;
        }
    }

    // GB6: Hangul L x (L|V|LV|VT)
    if (cp1_gbp_prop == .L) {
        if (cp2_gbp_prop == .L or
            cp2_gbp_prop == .V or
            cp2_gbp_prop == .LV or
            cp2_gbp_prop == .LVT) return false;
    }

    // GB7: Hangul (LV | V) x (V | T)
    if (cp1_gbp_prop == .LV or cp1_gbp_prop == .V) {
        if (cp2_gbp_prop == .V or
            cp2_gbp_prop == .T) return false;
    }

    // GB8: Hangul (LVT | T) x T
    if (cp1_gbp_prop == .LVT or cp1_gbp_prop == .T) {
        if (cp2_gbp_prop == .T) return false;
    }

    // GB9c: Indic Conjunct Break
    if (state.hasIndic() and
        cp1_indic_prop == .InCB_Consonant and
        (cp2_indic_prop == .InCB_Extend or cp2_indic_prop == .InCB_Linker))
    {
        return false;
    }

    if (state.hasIndic() and
        cp1_indic_prop == .InCB_Extend and
        cp2_indic_prop == .InCB_Linker)
    {
        return false;
    }

    if (state.hasIndic() and
        (cp1_indic_prop == .InCB_Linker or cp1_gbp_prop == .ZWJ) and
        cp2_indic_prop == .InCB_Consonant)
    {
        state.unsetIndic();
        return false;
    }

    return true;
}

test "Segmentation ZWJ and ZWSP emoji sequences" {
    const seq_1 = "\u{1F43B}\u{200D}\u{2744}\u{FE0F}";
    const seq_2 = "\u{1F43B}\u{200D}\u{2744}\u{FE0F}";
    const with_zwj = seq_1 ++ "\u{200D}" ++ seq_2;
    const with_zwsp = seq_1 ++ "\u{200B}" ++ seq_2;
    const no_joiner = seq_1 ++ seq_2;

    var iter = Iterator.init(with_zwj);

    var i: usize = 0;
    while (iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 1), i);

    iter = Iterator.init(with_zwsp);
    i = 0;
    while (iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 3), i);

    iter = Iterator.init(no_joiner);
    i = 0;
    while (iter.next()) |_| : (i += 1) {}
    try std.testing.expectEqual(@as(usize, 2), i);
}
