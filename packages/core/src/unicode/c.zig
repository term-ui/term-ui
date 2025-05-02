pub const c = @cImport({
    @cInclude("ICU4XDataProvider.h");
    @cInclude("ICU4XLineSegmenter.h");
    @cInclude("ICU4XCodePointMapData8.h");
});

pub usingnamespace c;
