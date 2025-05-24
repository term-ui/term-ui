const db = @import("db.zig");
const lookups = @import("lookups.zig");

pub const codepoint = struct {
    pub fn getLineBreak(c: u21) lookups.LineBreak {
        return db.getValue(lookups.LineBreak, c);
    }
    pub fn getCategory(c: u21) lookups.GeneralCategory {
        return db.getValue(lookups.GeneralCategory, c);
    }
    pub fn getEastAsianWidth(c: u21) db.EastAsianWidth {
        return db.getValue(db.EastAsianWidth, c);
    }
    pub fn isEmoji(c: u21) bool {
        return db.getBoolValue(lookups.EmojiIndex, c);
    }
    pub fn isEmojiPresentation(c: u21) bool {
        return db.getBoolValue(lookups.EmojiPresentationIndex, c);
    }
    pub fn isEmojiModifier(c: u21) bool {
        return db.getBoolValue(lookups.EmojiModifierIndex, c);
    }
    pub fn isEmojiModifierBase(c: u21) bool {
        return db.getBoolValue(lookups.EmojiModifierBaseIndex, c);
    }
    pub fn isEmojiComponent(c: u21) bool {
        return db.getBoolValue(lookups.EmojiComponentIndex, c);
    }
    pub fn isExtendedPictographic(c: u21) bool {
        return db.getBoolValue(lookups.ExtendedPictographicIndex, c);
    }

    fn isZeroWidth(c: u21) bool {
        const cat = getCategory(c);
        if (c <= 0x1F or (c >= 0x7F and c <= 0x9F)) return true;
        return switch (cat) {
            .Mn, .Me, .Cf => true,
            else => false,
        };
    }

    fn isFullWidth(c: u21) bool {
        return switch (getEastAsianWidth(c)) {
            .F, .W => true,
            else => false,
        };
    }

    fn isAmbiguous(c: u21) bool {
        return getEastAsianWidth(c) == .A;
    }

    pub fn visibleWidth(cp: u21, ambiguous_as_wide: bool) u3 {
        if (isZeroWidth(cp)) return 0;
        if (isFullWidth(cp)) return 2;
        if (ambiguous_as_wide and isAmbiguous(cp)) return 2;
        return 1;
    }

    pub fn visibleWidth32(cp: u32, ambiguous_as_wide: bool) u3 {
        return @This().visibleWidth(@as(u21, @intCast(cp)), ambiguous_as_wide);
    }
};
