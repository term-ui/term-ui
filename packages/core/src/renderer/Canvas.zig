const std = @import("std");
const Array = std.ArrayListUnmanaged;
const Point = @import("../layout/point.zig").Point;
const PointU32 = Point(u32);
const Color = @import("../colors/Color.zig");
const string_width = @import("../uni/string-width.zig");
const grapheme = @import("../layout/grapheme.zig");
const assert = std.debug.assert;
const styles = @import("../styles/styles.zig");
const ComputedGradient = @import("gradient.zig").ComputedGradient;
const Sampler = @import("gradient.zig").Sampler;
const RadialGradientSampler = @import("gradient.zig").RadialGradientSampler;
const debug = @import("../debug.zig");
pub const LayoutRect = @import("../layout/rect.zig").Rect;

cells: Array(Cell) = .{},
previous_cells: Array(Cell) = .{},

force_redraw: bool = true,
clear_color: Color = Color.tw.black,
fg_color: Color = Color.tw.white,
allocator: std.mem.Allocator,
size: PointU32,
is_continuation: bool = false,
mask: Rect,

anti_aliasing_samples: u32 = 1, // Default to 1 (no anti-aliasing) for better performance
render_buffer: std.ArrayListUnmanaged(u8) = .{}, // Buffer for rendering output

const Self = @This();
pub fn resize(self: *Self, size: Point(u32)) !void {
    debug.assert(size.x > 0, "canvas width must be positive: {d}", .{size.x});
    debug.assert(size.y > 0, "canvas height must be positive: {d}", .{size.y});

    if (size.x == self.size.x and size.y == self.size.y) {
        try self.clear();
        return;
    }
    self.size = size;
    self.mask = Rect.init(0, 0, @floatFromInt(size.x), @floatFromInt(size.y));
    self.force_redraw = true;
    try self.clear();
}

pub const Rect = struct {
    pos: Point(f32),
    size: Point(f32),

    pub fn init(x: f32, y: f32, width: f32, height: f32) Rect {
        return Rect{
            .pos = .{ .x = x, .y = y },
            .size = .{ .x = width, .y = height },
        };
    }
    pub fn right(self: Rect) f32 {
        return self.pos.x + self.size.x;
    }
    pub fn bottom(self: Rect) f32 {
        return self.pos.y + self.size.y;
    }
    pub fn left(self: Rect) f32 {
        return self.pos.x;
    }
    pub fn top(self: Rect) f32 {
        return self.pos.y;
    }
    pub fn isZero(self: Rect) bool {
        return self.size.x == 0 or self.size.y == 0;
    }

    pub fn isPointWithin(self: Rect, comptime T: type, point: Point(T)) bool {
        const x: f32, const y: f32 = switch (T) {
            f32 => .{ point.x, point.y },
            u32 => .{
                @floatFromInt(point.x),
                @floatFromInt(point.y),
            },
            else => unreachable,
        };
        return x >= self.left() and x < self.right() and y >= self.top() and y < self.bottom();
    }
    pub fn isRectCompletelyWithin(self: Rect, other: Rect) bool {
        return self.pos.x >= other.pos.x and
            self.pos.x + self.size.x <= other.pos.x + other.size.x and
            self.pos.y >= other.pos.y and
            self.pos.y + self.size.y <= other.pos.y + other.size.y;
    }
    pub fn intersectsWith(self: Rect, other: Rect) bool {
        return self.pos.x < other.pos.x + other.size.x and self.pos.x + self.size.x > other.pos.x and self.pos.y < other.pos.y + other.size.y and self.pos.y + self.size.y > other.pos.y;
    }

    pub fn intersect(self: Rect, other: Rect) Rect {
        // Calculate the top-left point of the intersection (max of both top-left points)
        const x1 = @max(self.pos.x, other.pos.x);
        const y1 = @max(self.pos.y, other.pos.y);

        // Calculate the bottom-right point of the intersection (min of both bottom-right points)
        const x2 = @min(self.pos.x + self.size.x, other.pos.x + other.size.x);
        const y2 = @min(self.pos.y + self.size.y, other.pos.y + other.size.y);

        // Calculate dimensions (handle case where rectangles don't overlap)
        const width = if (x2 > x1) x2 - x1 else 0;
        const height = if (y2 > y1) y2 - y1 else 0;

        return Rect{
            .pos = .{ .x = x1, .y = y1 },
            .size = .{ .x = width, .y = height },
        };
    }
    pub fn round(self: Rect) Rect {
        return Rect{
            .pos = .{ .x = @round(self.pos.x), .y = @round(self.pos.y) },
            .size = .{ .x = @round(self.size.x), .y = @round(self.size.y) },
        };
    }

    pub fn format(value: Rect, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; // autofix
        _ = options; // autofix
        try writer.print("Rect[x={d}, y={d}, w={d}, h={d}]", .{ value.pos.x, value.pos.y, value.size.x, value.size.y });
    }
    pub fn move(self: Rect, dx: u32, dy: u32) Rect {
        return Rect{
            .pos = .{ .x = self.pos.x + dx, .y = self.pos.y + dy },
            .size = self.size,
        };
    }
};

/// Text formatting options for a cell
pub const TextFormat = struct {
    is_bold: bool = false,
    is_italic: bool = false,
    is_dim: bool = false,

    decoration_line: styles.text_decoration.TextDecorationLine = .none,
    decoration_color: ?Color = null,
    decoration_thickness: f32 = 1.0,

    /// Set text format based on style properties
    pub fn fromStyle(font_weight: styles.font_weight.FontWeight, font_style: styles.font_style.FontStyle, text_decoration: styles.text_decoration.TextDecoration) TextFormat {
        return TextFormat{
            .is_bold = font_weight == .bold,
            .is_italic = font_style == .italic,
            .is_dim = font_weight == .dim,
            .decoration_line = text_decoration.line,
            .decoration_color = text_decoration.color,
            .decoration_thickness = text_decoration.thickness,
        };
    }
    pub fn equal(self: TextFormat, other: TextFormat) bool {
        if (self.is_bold != other.is_bold or
            self.is_italic != other.is_italic or
            self.is_dim != other.is_dim or
            self.decoration_line != other.decoration_line or
            self.decoration_thickness != other.decoration_thickness)
        {
            return false;
        }

        if (self.decoration_color) |a| {
            if (other.decoration_color) |b| {
                return a.equal(b);
            }
            return false;
        }
        return true;
    }
};

const Cell = struct {
    data: union(enum) {
        text: struct {
            buf: std.BoundedArray(u8, 32) = .{},
            formatting: TextFormat = .{},
        },
        border_char: styles.border.BoxChar,
        pub fn equal(self: @This(), other: @This()) bool {
            switch (self) {
                .text => |text| {
                    switch (other) {
                        .text => |other_text| {
                            return text.formatting.equal(other_text.formatting) and std.mem.eql(u8, text.buf.slice(), other_text.buf.slice());
                        },
                        else => return false,
                    }
                },
                .border_char => |border_char| {
                    switch (other) {
                        .border_char => |other_border_char| {
                            return border_char.encode() == other_border_char.encode();
                        },
                        else => return false,
                    }
                },
            }
        }
    } = .{ .text = .{} },
    width: u32 = 0,
    fg: Color = Color.tw.white,
    bg: Color = Color.tw.black,
    pub fn setText(self: *Cell, chars: []const u8, width: u32, formatting: TextFormat) void {
        self.data = .{ .text = .{ .formatting = formatting } };
        self.data.text.buf.appendSlice(chars) catch std.debug.panic("failed to append slice", .{});
        self.width = width;
        // self.formatting = formatting;
    }
    pub fn setBorderChar(self: *Cell, border_char: styles.border.BoxChar) void {
        switch (self.data) {
            .text => {
                self.data = .{ .border_char = border_char };
                self.width = 1;
            },
            .border_char => {
                if (border_char.s.style != .none) {
                    self.data.border_char.s = border_char.s;
                }
                if (border_char.n.style != .none) {
                    self.data.border_char.n = border_char.n;
                }
                if (border_char.e.style != .none) {
                    self.data.border_char.e = border_char.e;
                }
                if (border_char.w.style != .none) {
                    self.data.border_char.w = border_char.w;
                }

                // self.data = .{ .border_char = border_char };
                self.width = 1;
            },
        }
    }
    pub fn equal(self: *Cell, other: *Cell) bool {
        // if (self.width != other.width or !self.bg.equal(other.bg) or !self.fg.equal(other.fg) or !self.data.text.formatting.equal(other.data.text.formatting)) {
        //     return false;
        // }
        // switch (self.data) {
        //     .text => {
        //         if (!std.mem.eql(u8, self.data.text.buf.slice(), other.data.text.buf.slice())) {
        //             return false;
        //         }

        //         return true;
        //     },
        //     .border_char => {
        //         return self.data.border_char.encode() == other.data.border_char.encode();
        //     },
        // }

        return self.width == other.width and self.bg.equal(other.bg) and self.fg.equal(other.fg) and self.data.equal(other.data);
        // return std.mem.eql(u8, std.mem.asBytes(self), std.mem.asBytes(other));
    }
    pub fn clear(self: *Cell, clear_color: Color, fg_color: Color) void {
        self.clearText();
        self.fg = fg_color;
        self.bg = clear_color;
    }
    pub fn clearText(self: *Cell) void {
        self.data = .{ .text = .{} };
        self.width = 0;
    }
    pub fn isEmpty(self: *Cell) bool {
        return self.width == 0;
    }
    pub fn compositeBg(self: *Cell, color: Color, mode: ?Color.CompositeOperation) void {
        self.bg = Color.composite(color, self.bg, mode orelse .source_over);

        self.clearText();
    }
    pub fn setFg(self: *Cell, color: Color) void {
        self.fg = Color.composite(color, self.bg, .source_over);
    }
    pub fn format(self: *Cell, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; // autofix
        _ = options; // autofix
        try writer.writeAll("Cell[");
        switch (self.data) {
            .text => |text| {
                try writer.print("text={any} ", .{text.buf.slice()});
                if (text.formatting.is_bold) {
                    try writer.print("bold ", .{});
                }
                if (text.formatting.is_italic) {
                    try writer.print("italic ", .{});
                }
                if (text.formatting.is_dim) {
                    try writer.print("dim ", .{});
                }
                try writer.print("decoration_line={s}, ", .{@tagName(text.formatting.decoration_line)});
                if (text.formatting.decoration_color) |color| {
                    try writer.print("decoration_color={any} ", .{color});
                }
                if (text.formatting.decoration_thickness > 0) {
                    try writer.print("decoration_thickness={d} ", .{text.formatting.decoration_thickness});
                }
            },
            .border_char => |border_char| {
                try writer.print("border_char={d} ", .{border_char.encode()});
            },
        }
        try writer.print("width={d} fg={any} bg={any}]", .{ self.width, self.fg, self.bg });
        //     _ = fmt; // autofix
        //     _ = options; // autofix
        // try writer.print("Cell[chars={any}, width={d}, fg={any}, bg={any}, format={any}]", .{ self.data.text.buf, self.width, self.fg, self.bg, self.data.text.formatting });
    }
};

pub fn init(allocator: std.mem.Allocator, size: Point(u32), clear_color: Color, fg_color: Color) !Self {
    const self = Self{
        .allocator = allocator,
        .size = size,
        .clear_color = clear_color,
        .fg_color = fg_color,
        .mask = Rect.init(0, 0, @floatFromInt(size.x), @floatFromInt(size.y)),
        .anti_aliasing_samples = 1, // Default to no anti-aliasing
    };

    return self;
}

pub fn deinit(self: *Self) void {
    self.cells.deinit(self.allocator);
    self.previous_cells.deinit(self.allocator);
    self.render_buffer.deinit(self.allocator);
}

pub fn resetMask(self: *Self) void {
    self.mask = Rect.init(0, 0, @floatFromInt(self.size.x), @floatFromInt(self.size.y));
}
pub fn clear(self: *Self) !void {
    // std.debug.print("clearing canvas\n", .{});
    const len = self.size.x * self.size.y;
    debug.assert(len > 0, "canvas area must be positive: {d}", .{len});

    try self.cells.ensureTotalCapacity(self.allocator, len);
    self.cells.items.len = len;
    // self.cells.clearRetainingCapacity();

    const cell = Cell{
        .fg = self.fg_color,
        .bg = self.clear_color,
    };
    for (0..len) |i| {
        self.cells.items[i] = cell;
    }

    // try self.cells.appendNTimes(self.allocator, cell, len);
    debug.assert(self.cells.items.len == len, "cell count doesn't match canvas size: cell count={d}, expected={d}", .{ self.cells.items.len, len });
    debug.assert(self.cells.items.len == len, "cell count doesn't match canvas size: cell count={d}, expected={d}", .{ self.cells.items.len, len });
}
pub fn setMask(self: *Self, mask: Rect) void {
    debug.assert(mask.pos.x >= 0, "mask x position must be non-negative: {d}", .{mask.pos.x});
    debug.assert(mask.pos.y >= 0, "mask y position must be non-negative: {d}", .{mask.pos.y});
    debug.assert(mask.size.x >= 0, "mask width must be non-negative: {d}", .{mask.size.x});
    debug.assert(mask.size.y >= 0, "mask height must be non-negative: {d}", .{mask.size.y});

    self.mask.size.x = @min(self.size.x - mask.pos.x, mask.size.x);
    self.mask.size.y = @min(self.size.y - mask.pos.y, mask.size.y);

    debug.assert(self.mask.size.x >= 0, "calculated mask width is negative: {d}", .{self.mask.size.x});
    debug.assert(self.mask.size.y >= 0, "calculated mask height is negative: {d}", .{self.mask.size.y});
}
pub fn getMaxX(self: *Self) u32 {
    debug.assert(self.mask.size.x >= 0, "mask size x must be non-negative: {d}", .{self.mask.size.x});
    debug.assert(self.mask.pos.x >= 0, "mask position x must be non-negative: {d}", .{self.mask.pos.x});
    return @intFromFloat(self.mask.size.x + self.mask.pos.x);
}
pub fn getMinX(self: *Self) u32 {
    debug.assert(self.mask.pos.x >= 0, "mask position x must be non-negative: {d}", .{self.mask.pos.x});
    return @intFromFloat(self.mask.pos.x);
}
pub fn getMaxY(self: *Self) u32 {
    debug.assert(self.mask.size.y >= 0, "mask size y must be non-negative: {d}", .{self.mask.size.y});
    debug.assert(self.mask.pos.y >= 0, "mask position y must be non-negative: {d}", .{self.mask.pos.y});
    return @intFromFloat(self.mask.size.y + self.mask.pos.y);
}
pub fn getMinY(self: *Self) u32 {
    debug.assert(self.mask.pos.y >= 0, "mask position y must be non-negative: {d}", .{self.mask.pos.y});
    return @intFromFloat(self.mask.pos.y);
}

pub fn fetchCell(self: *Self, comptime T: type, pos: Point(T)) *Cell {
    debug.assert(self.size.x > 0, "canvas width must be positive: {d}", .{self.size.x});
    debug.assert(self.size.y > 0, "canvas height must be positive: {d}", .{self.size.y});

    const index: usize = switch (T) {
        u32 => @intCast(pos.x + pos.y * self.size.x),
        f32 => index: {
            const x: u32 = @intFromFloat(@round(pos.x));
            const y: u32 = @intFromFloat(@round(pos.y));
            debug.assert(x < self.size.x, "x coordinate out of bounds: x={d}, width={d}", .{ x, self.size.x });
            debug.assert(y < self.size.y, "y coordinate out of bounds: y={d}, height={d}", .{ y, self.size.y });
            break :index @intCast(x + y * self.size.x);
        },
        else => unreachable,
    };
    debug.assert(index < self.cells.items.len, "trying to fetch cell at {any} but index is {d} and len is {d}\n", .{ pos, index, self.cells.items.len });
    return &self.cells.items[index];
}
pub fn setChar(self: *Self, pos: Point(f32), width: f32, chars: []const u8, maybe_fg: ?styles.color.Color, formatting: ?TextFormat) void {
    debug.assert(Rect.init(pos.x, pos.y, width, 1).isRectCompletelyWithin(self.mask.round()), "setChar: position out of bounds: {any}", .{pos});

    // const cell_end = @floor(width + pos.x);

    // const cell_start = @ceil(pos.x);

    var cell = self.fetchCell(f32, pos);

    cell.setText(chars, @intFromFloat(width), formatting orelse .{});

    if (maybe_fg) |fg| {
        cell.setFg(fg);
    }

    debug.assert(cell.width > 0, "cell width must be positive: {d}", .{cell.width});
}

pub fn drawRectBg(self: *Self, rect: Rect, bg_param: styles.background.Background) !void {
    const clamp_rect = rect.intersect(self.mask).round();
    if (clamp_rect.isZero()) {
        return;
    }

    // Handle different background types
    switch (bg_param) {
        .solid => |color| {
            // Original behavior for solid color
            var y = clamp_rect.pos.y;
            var i: usize = 0;
            while (y < clamp_rect.pos.y + clamp_rect.size.y) : (y += 1) {
                var x = @round(clamp_rect.pos.x);
                while (x < @round(clamp_rect.right())) : (x += 1) {
                    i += 1;
                    var cell = self.fetchCell(f32, .{ .x = x, .y = y });
                    cell.compositeBg(color, null);
                }
            }
            debug.assert(i > 0 or (clamp_rect.size.x == 0 or clamp_rect.size.y == 0), "no cells were processed in drawRectBg", .{});
        },
        .linear_gradient => |gradient| {
            debug.assert(gradient.color_stops.len > 0, "linear gradient must have at least one color stop", .{});

            var sampler = try ComputedGradient.init(
                self.allocator,
                rect.size,
                gradient.angle,
                gradient.color_stops.slice(),
                true,
            );
            defer sampler.deinit();
            var y = clamp_rect.pos.y;
            while (y < clamp_rect.pos.y + clamp_rect.size.y) : (y += 1) {
                var x = clamp_rect.pos.x;
                while (x < clamp_rect.pos.x + clamp_rect.size.x) : (x += 1) {
                    const color = sampler.at(.{ .x = x - clamp_rect.pos.x, .y = y - clamp_rect.pos.y });
                    var cell = self.fetchCell(f32, .{ .x = x, .y = y });
                    cell.compositeBg(color, null);
                }
            }
        },
        .radial_gradient => |gradient| {
            debug.assert(gradient.color_stops.len > 0, "radial gradient must have at least one color stop", .{});

            var sampler = try RadialGradientSampler.init(
                self.allocator,
                rect.size,
                gradient,
                true,
            );

            defer sampler.deinit();
            var y = clamp_rect.pos.y;
            while (y < clamp_rect.pos.y + clamp_rect.size.y) : (y += 1) {
                var x = clamp_rect.pos.x;
                while (x < clamp_rect.pos.x + clamp_rect.size.x) : (x += 1) {
                    const color = sampler.at(.{ .x = x - clamp_rect.pos.x, .y = y - clamp_rect.pos.y });
                    var cell = self.fetchCell(f32, .{ .x = x, .y = y });
                    cell.compositeBg(color, null);
                }
            }
        },
        // else => {},
    }
}

/// Draw a string with formatting options
pub fn drawStringFormatted(self: *Self, pos: Point(f32), text: []const u8, maybe_fg: ?styles.color.Color, format: TextFormat) !void {
    const rounded_pos: Point(f32) = pos.round();
    var iter = try grapheme.GraphemeIterator.init(text);
    const full_width = string_width.visible.width.exclude_ansi_colors.utf8(text);
    const rect = Rect.init(rounded_pos.x, rounded_pos.y, @floatFromInt(full_width), 1);
    const rounded_mask = self.mask.round();
    const clamp_rect = rect.intersect(rounded_mask);
    if (clamp_rect.isZero()) {
        return;
    }
    var x = rounded_pos.x;

    while (iter.next()) |slice| {
        const width: f32 = @floatFromInt(string_width.visible.width.exclude_ansi_colors.utf8(slice));
        debug.assert(width > 0, "trying to drawing zero width string", .{});

        const start = x;
        x += width;
        if (start < rounded_mask.pos.x) continue;

        if (x > rounded_mask.right()) {
            break;
        }

        self.setChar(
            .{ .x = start, .y = rounded_pos.y },
            width,
            slice,
            maybe_fg,
            format,
        );
    }
}

/// Draw a decoration line (underline, strikethrough, etc.)
fn drawDecorationLine(self: *Self, pos: Point(f32), width: f32, decoration_type: styles.text_decoration.TextDecorationLine, color: styles.color.Color, thickness: f32) void {
    _ = thickness; // autofix

    // For now, we'll keep this simple since we're in a terminal
    // We'll just set special decoration markers in cells

    // In a real implementation, this would draw the actual decoration
    // using terminal escape sequences or other rendering methods

    const y_offset: f32 = switch (decoration_type) {
        .line_through => 0.0, // Middle of text
        .underline, .double, .dashed, .wavy => 1.0, // Below text
        else => 0.0, // No decoration
    };

    // Mark cells with decoration info
    var x: f32 = pos.x;
    const end_x = @min(pos.x + width, @as(f32, @floatFromInt(self.size.x)));

    while (x < end_x) {
        const cell_x: u32 = @intFromFloat(@floor(x));
        const cell_y: u32 = @intFromFloat(@floor(pos.y + y_offset));

        debug.assert(cell_x < self.size.x, "cell x coordinate out of bounds: x={d}, width={d}", .{ cell_x, self.size.x });
        debug.assert(cell_y < self.size.y, "cell y coordinate out of bounds: y={d}, height={d}", .{ cell_y, self.size.y });

        if (cell_x >= self.getMinX() and cell_x < self.getMaxX() and
            cell_y >= self.getMinY() and cell_y < self.getMaxY())
        {
            var cell = self.fetchCell(.{ .x = cell_x, .y = cell_y });

            // For strikethrough, we need to make sure we don't overwrite text
            if (decoration_type == .line_through) {
                // Only set decoration info if this is part of the text
                if (cell.width > 0) {
                    cell.formatting.decoration_line = decoration_type;
                    cell.formatting.decoration_color = color;
                }
            } else {
                // For underlines, we can use separate cells below the text
                cell.formatting.decoration_line = decoration_type;
                cell.formatting.decoration_color = color;

                // If the cell has no text (for decorations that go below text),
                // we need to make it visible without showing a character
                if (cell.width == 0) {
                    cell.width = 1; // Make it take space
                    cell.chars = &[_]u8{};
                }
            }
        }

        x += 1.0;
    }
}

/// Simplified version of drawString for backward compatibility
pub fn drawString(self: *Self, pos: Point(f32), text: []const u8, maybe_fg: ?styles.color.Color) !void {
    return self.drawStringFormatted(pos, text, maybe_fg, .{});
}

fn writeFgSequence(writer: std.io.AnyWriter, fg: Color) !void {
    const r, const g, const b = fg.toU8RGB();

    try writer.print("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
}
fn writeBgSequence(writer: std.io.AnyWriter, bg: Color) !void {
    const r, const g, const b = bg.toU8RGB();

    try writer.print("\x1b[48;2;{d};{d};{d}m", .{ r, g, b });
}
fn writeFormattingSequence(writer: std.io.AnyWriter, current_format: TextFormat, new_format: TextFormat) !void {
    if (current_format.is_bold != new_format.is_bold) {
        if (new_format.is_bold) {
            // enable bold
            try writer.print("\x1b[1m", .{});
        } else {
            // disable bold
            try writer.print("\x1b[22m", .{});
        }
    }
    if (current_format.is_italic != new_format.is_italic) {
        if (new_format.is_italic) {
            // enable italic
            try writer.print("\x1b[3m", .{});
        } else {
            // disable italic
            try writer.print("\x1b[23m", .{});
        }
    }
    if (current_format.decoration_line == .line_through and new_format.decoration_line != .line_through) {
        try writer.print("\x1b[29m", .{});
    }
    if (current_format.decoration_line != new_format.decoration_line) {
        switch (new_format.decoration_line) {
            .underline => {
                try writer.print("\x1b[4m", .{});
            },
            .line_through => {
                try writer.print("\x1b[9m", .{});
            },
            .double => {
                try writer.print("\x1b[4:2m", .{}); // Double underline
            },
            .dashed => {
                try writer.print("\x1b[4:4m", .{}); // Dotted underline
            },
            .wavy => {
                try writer.print("\x1b[4:3m", .{}); // Curly/wavy underline
            },
            .none => {
                try writer.print("\x1b[24m", .{});
            },
            .inherit => {
                std.debug.panic("inherit should be resolved by this point", .{});
            },
        }
    }

    // Handle decoration color with proper optional type handling
    const colors_changed = blk: {
        if (current_format.decoration_color == null and new_format.decoration_color == null) {
            break :blk false;
        }
        const current_color = current_format.decoration_color orelse break :blk true;
        const new_color = new_format.decoration_color orelse break :blk true;
        break :blk !current_color.equal(new_color);
    };

    if (colors_changed) {
        if (new_format.decoration_color) |color| {
            const r, const g, const b = color.toU8RGB();
            // Set underline color using RGB values
            try writer.print("\x1b[58:2:{d}:{d}:{d}m", .{ r, g, b });
        } else {
            // Reset to default underline color
            try writer.print("\x1b[59m", .{});
        }
    }
}

pub fn render(self: *Self, writer: std.io.AnyWriter, clear_screen: bool) !void {
    if (self.force_redraw or self.previous_cells.items.len != self.cells.items.len) {
        try self.renderInner(writer, clear_screen, true);
        self.force_redraw = false;
    } else {
        try self.renderInner(writer, clear_screen, false);
    }
}
pub fn moveCursorBy(writer: std.io.AnyWriter, x: i32, y: i32) !void {
    if (y > 0) {
        try writer.print("\x1b[{d}B", .{y});
    } else if (y < 0) {
        try writer.print("\x1b[{d}A", .{-y});
    }
    if (x > 0) {
        try writer.print("\x1b[{d}C", .{x});
    } else if (x < 0) {
        try writer.print("\x1b[{d}D", .{-x});
    }
}

pub fn renderInner(self: *Self, writer: std.io.AnyWriter, clear_screen: bool, comptime full_paint: bool) !void {
    // Clear the buffer
    self.render_buffer.clearRetainingCapacity();
    const buf_writer = self.render_buffer.writer(self.allocator).any();
    if (clear_screen) {
        try buf_writer.writeAll("\x1b[H");
    }

    var last_x: i32 = -1;
    var last_y: i32 = 0;
    // Render to buffer
    var y: u32 = 0;

    var bg = Color.tw.transparent;
    var fg = Color.tw.transparent;
    var current_format = TextFormat{};
    var is_equal = true;
    while (y < self.size.y) : (y += 1) {
        var x: u32 = 0;
        var skip_cells: usize = 0;
        while (x < self.size.x) : (x += 1) {
            debug.assert(x < self.size.x, "x coordinate out of bounds: x={d}, width={d}", .{ x, self.size.x });
            debug.assert(y < self.size.y, "y coordinate out of bounds: y={d}, height={d}", .{ y, self.size.y });

            const cell_index: usize = y * self.size.x + x;
            var cell = &self.cells.items[cell_index];
            if (comptime !full_paint) {
                var prev_cell = &self.previous_cells.items[cell_index];
                if (prev_cell.equal(cell)) {
                    continue;
                }
                const _y: i32 = @intCast(y);
                const _x: i32 = @intCast(x);
                const y_offset = _y - last_y;
                const x_offset = _x - (last_x + 1);
                // std.debug.print("last_pos: {d} {d}\n", .{ last_x, last_y });
                // std.debug.print("pos:      {d} {d}\n", .{ x, y });
                // std.debug.print("offset:   {d} {d}\n", .{ x_offset, y_offset });
                try moveCursorBy(buf_writer, x_offset, y_offset);
                // std.debug.print("moveCursorBy({d}, {d})\n", .{ x_offset, y_offset });

                last_x = _x;
                last_y = _y;
            }

            is_equal = false;
            // Apply background color if changed
            if (!cell.bg.equal(bg)) {
                bg = cell.bg;
                try writeBgSequence(buf_writer, bg);
            }
            if (skip_cells > 0) {
                skip_cells -= 1;
                continue;
            }

            // Apply foreground color if changed
            if (!cell.fg.equal(fg)) {
                fg = cell.fg;
                try writeFgSequence(buf_writer, fg);
            }

            const drawn_width: u32 = switch (cell.data) {
                .text => |data| blk: {
                    try writeFormattingSequence(buf_writer, current_format, data.formatting);
                    current_format = data.formatting;
                    if (cell.width == 0) {
                        try buf_writer.writeAll(" ");
                        break :blk 1;
                    } else {
                        try buf_writer.writeAll(data.buf.slice());
                        break :blk cell.width;
                    }
                },
                .border_char => |*border_cell| blk: {
                    try writeFormattingSequence(buf_writer, current_format, .{});
                    current_format = .{};
                    const border_char = border_cell.getChar();
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(border_char, buf[0..]) catch unreachable;
                    try buf_writer.writeAll(buf[0..len]);
                    break :blk 1;
                },
            };
            skip_cells = drawn_width - 1;
        }

        if (comptime full_paint) {
            const _x: i32 = @intCast(self.size.x);
            _ = _x; // autofix

            // try moveCursorBy(buf_writer, -_x, 1);
            current_format = .{};
            bg = Color.tw.transparent;
            fg = Color.tw.transparent;

            try buf_writer.writeAll("\x1b[0m|\n");
        }
    }
    if (comptime !full_paint) {
        if (is_equal) {
            return;
        }
        const _y: i32 = @intCast(y);
        const _x: i32 = 0;
        const y_offset = _y - last_y;
        const x_offset = -last_x - 1;

        try moveCursorBy(buf_writer, x_offset, y_offset);

        last_x = _x;
        last_y = _y;
    }

    try buf_writer.writeAll("\x1b[0m");

    self.previous_cells.clearRetainingCapacity();
    try self.previous_cells.appendSlice(self.allocator, self.cells.items);

    // // Write the buffer to the output
    // for (self.render_buffer.items) |c| {
    //     switch (c) {
    //         '\x1b' => {
    //             std.debug.print("\\e", .{});
    //         },
    //         else => {
    //             std.debug.print("{c}", .{c});
    //         },
    //     }
    // }
    // std.debug.print("\n\n", .{});
    // // if (!is_equal) {
    try writer.writeAll(self.render_buffer.items);
    // }
    // std.debug.print("written bytes: {d}\n", .{self.render_buffer.?.items.len});
}
pub fn drawRectBorder(self: *Self, _rect: Rect, border: LayoutRect(styles.border.BoxChar.Cell), border_color: LayoutRect(styles.background.Background)) !void {
    if (border.top.style == .none and border.bottom.style == .none and border.left.style == .none and border.right.style == .none) {
        return;
    }
    var rect = _rect.round();

    const clamp_rect = rect.intersect(self.mask).round();
    if (clamp_rect.isZero()) {
        return;
    }

    // const

    var top_sampler = try Sampler.from(self.allocator, border_color.top, rect.size);
    defer top_sampler.deinit();
    var bottom_sampler = try Sampler.from(self.allocator, border_color.bottom, rect.size);
    defer bottom_sampler.deinit();
    var left_sampler = try Sampler.from(self.allocator, border_color.left, rect.size);
    defer left_sampler.deinit();
    var right_sampler = try Sampler.from(self.allocator, border_color.right, rect.size);
    defer right_sampler.deinit();

    const will_draw_corners = rect.size.x > 1 and rect.size.y > 1;

    // std.debug.print("rect: {any}\nclamp_rect: {any}\n will_draw_corners: {}\n", .{ rect, clamp_rect, will_draw_corners });
    const will_render_top_line = clamp_rect.top() == rect.top() and rect.size.x > 1;
    const will_render_bottom_line = clamp_rect.bottom() == rect.bottom() and rect.size.x > 1;

    const will_render_left_line = clamp_rect.left() == rect.left() and rect.size.y > 1;
    const will_render_right_line = clamp_rect.right() == rect.right() and rect.size.y > 1;

    const top_cell_style: styles.border.BoxChar = if (will_render_top_line) .{ .w = border.top, .e = border.top } else .{};
    const bottom_cell_style: styles.border.BoxChar = if (will_render_bottom_line) .{ .w = border.bottom, .e = border.bottom } else .{};
    const left_cell_style: styles.border.BoxChar = if (will_render_left_line) .{ .n = border.left, .s = border.left } else .{};
    const right_cell_style: styles.border.BoxChar = if (will_render_right_line) .{ .n = border.right, .s = border.right } else .{};

    const left = clamp_rect.left();
    const right = @max(clamp_rect.right() - 1, 0);
    const top = clamp_rect.top();
    const bottom = @max(clamp_rect.bottom() - 1, 0);

    if (will_draw_corners) {
        if (will_render_left_line and will_render_top_line) {
            // top left
            const point: Point(f32) = .{ .x = left, .y = top };
            if (self.mask.isPointWithin(f32, point)) {
                var top_left_cell = self.fetchCell(f32, point);

                // top_left_cell.border.s = left_cell_style.n;
                // top_left_cell.border.e = top_cell_style.w;
                top_left_cell.setBorderChar(.{
                    .s = left_cell_style.n,
                    .e = top_cell_style.w,
                });
                top_left_cell.setFg(top_sampler.at(.{ .x = 0, .y = 0 }));
            }
        }
        if (will_render_right_line and will_render_top_line) {
            const point: Point(f32) = .{ .x = right, .y = top };
            if (self.mask.isPointWithin(f32, point)) {
                // top right
                var top_right_cell = self.fetchCell(f32, point);
                // top_right_cell.border |= top_right_cell_style.encode();
                top_right_cell.setBorderChar(.{
                    .s = right_cell_style.n,
                    .w = top_cell_style.e,
                });
                top_right_cell.setFg(top_sampler.at(.{ .x = rect.size.x, .y = 0 }));
            }
        }
        if (will_render_left_line and will_render_bottom_line) {
            const point: Point(f32) = .{ .x = left, .y = bottom };
            if (self.mask.isPointWithin(f32, point)) {
                // bottom left
                var bottom_left_cell = self.fetchCell(f32, point);
                bottom_left_cell.setBorderChar(.{
                    .n = left_cell_style.s,
                    .e = bottom_cell_style.w,
                });
                bottom_left_cell.setFg(bottom_sampler.at(.{ .x = 0, .y = rect.size.y }));
            }
        }
        if (will_render_right_line and will_render_bottom_line) {
            const point: Point(f32) = .{ .x = right, .y = bottom };
            if (self.mask.isPointWithin(f32, point)) {
                // bottom right
                var bottom_right_cell = self.fetchCell(f32, point);
                bottom_right_cell.setBorderChar(.{
                    .n = right_cell_style.s,
                    .w = bottom_cell_style.e,
                });
                bottom_right_cell.setFg(bottom_sampler.at(.{ .x = rect.size.x, .y = rect.size.y }));
            }
        }
    }
    var x = left;
    if (will_render_left_line and will_draw_corners) {
        x += 1;
    }
    // const x_end = right + @floatFromInt(@intFromBool(will_render_right_line));
    var x_end = right;
    if (will_render_right_line and will_draw_corners) {
        x_end -= 1;
    }
    while (x <= x_end) : (x += 1) {
        if (will_render_top_line) {
            const top_cell = self.fetchCell(f32, .{ .x = x, .y = top });
            top_cell.setBorderChar(.{
                .w = top_cell_style.w,
                .e = top_cell_style.e,
            });
            top_cell.setFg(top_sampler.at(.{ .x = x - rect.left(), .y = 0 }));
        }
        if (will_render_bottom_line) {
            const bottom_cell = self.fetchCell(f32, .{ .x = x, .y = bottom });

            bottom_cell.setBorderChar(.{
                .w = bottom_cell_style.w,
                .e = bottom_cell_style.e,
            });
            bottom_cell.setFg(bottom_sampler.at(.{ .x = x - rect.left(), .y = rect.size.y }));
        }
    }

    var y = top;
    if (will_render_top_line and will_draw_corners) {
        y += 1;
    }
    var y_end = bottom;
    if (will_render_bottom_line and will_draw_corners) {
        y_end -= 1;
    }
    while (y <= y_end) : (y += 1) {
        if (will_render_left_line) {
            const left_cell = self.fetchCell(f32, .{ .x = left, .y = y });
            left_cell.setBorderChar(.{
                .n = left_cell_style.n,
                .s = left_cell_style.s,
            });
            left_cell.setFg(left_sampler.at(.{ .x = 0, .y = y - rect.top() }));
        }
        if (will_render_right_line) {
            const right_cell = self.fetchCell(f32, .{ .x = right, .y = y });
            right_cell.setBorderChar(.{
                .n = right_cell_style.n,
                .s = right_cell_style.s,
            });
            right_cell.setFg(right_sampler.at(.{ .x = rect.size.x, .y = y - rect.top() }));
        }
    }
}
test "canvas" {
    try styles.border.BoxChar.load();
    var canvas = try init(
        std.testing.allocator,
        .{ .x = 5, .y = 3 },
        Color.tw.black,
        Color.tw.white,
    );
    try canvas.clear();
    defer canvas.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const writer = std.io.getStdErr().writer().any();
    // try writer.writeAll("\x1b[?7l");
    // try writer.print("--------------------------------\n", .{});
    try canvas.drawRectBg(Rect.init(0, 0, 5, 3), .{ .solid = Color.tw.indigo_500 });
    // try canvas.drawString(.{ .x = 0, .y = 0 }, "A", null);
    try canvas.drawString(.{ .x = 2, .y = 1 }, "B", null);
    try canvas.drawString(.{ .x = 3, .y = 2 }, "C", null);
    try canvas.drawString(.{ .x = 4, .y = 3 }, "D", null);
    try canvas.render(writer, true);

    try canvas.clear();
    try canvas.drawRectBg(Rect.init(0, 0, 5, 3), .{ .solid = Color.tw.indigo_500 });
    try writer.print("--------------------------------\n", .{});
    // try canvas.drawString(.{ .x = 0, .y = 0 }, "a", null);
    try canvas.drawString(.{ .x = 2, .y = 1 }, "b", null);
    try canvas.drawString(.{ .x = 3, .y = 2 }, "c", null);
    try canvas.drawString(.{ .x = 4, .y = 3 }, "d", null);
    // try canvas.drawString(.{ .x = 2, .y = 2 }, "AbcDef", null);
    try canvas.render(writer, false);
}

pub fn renderToHtml(self: *Self, writer: std.io.AnyWriter) !void {
    try writer.writeAll("<!DOCTYPE html>\n<html>\n");
    try writer.writeAll("<head>\n");
    try writer.writeAll("<style>\n");
    try writer.writeAll(
        \\body { margin: 0; padding: 20px; background-color: #1a1a1a; font-family: system-ui, -apple-system, sans-serif; }
        \\* { box-sizing: border-box; }
        \\.canvas { font-family: 'Courier New', monospace; position: relative; margin: 20px auto; overflow: hidden; background-color: black; border-radius: 4px; box-shadow: 0 4px 8px rgba(0,0,0,0.2); }
        \\.row { display: flex; flex-wrap: nowrap; flex-direction: row; width: 100%; }
        \\.cell { display: inline-flex; align-items: center; justify-content: center; vertical-align: top; flex-shrink: 0; flex-grow: 0; overflow: visible; text-align: center; user-select: none; font-size: 16px; line-height: 1; border: 1px solid rgba(255,255,255,0.05); cursor: pointer; }
        \\.cell:hover { box-shadow: inset 0 0 0 1px rgba(255,255,255,0.3); }
        \\.cell.cell-highlight { outline: 2px solid rgba(255, 215, 0, 0.8); outline-offset: -2px; position: relative; z-index: 1; }
        \\.cell.cell-hover { outline: 2px dashed rgba(100, 200, 255, 0.7); outline-offset: -2px; position: relative; z-index: 1; }
        \\#cell-details { font-family: monospace; background-color: #292929; color: #eee; padding: 10px; margin-top: 20px; border-radius: 4px; max-width: 100%; overflow: auto; white-space: pre-wrap; display: none; }
    );
    try writer.writeAll("</style>\n");
    try writer.writeAll("</head>\n");
    try writer.writeAll("<body>\n");

    const cell_width: u32 = 12;
    const cell_height: u32 = 22;
    try writer.print("<div class=\"canvas\" style=\"width:{d}px;height:{d}px;\">\n", .{ self.size.x * cell_width, self.size.y * cell_height });

    var y: u32 = 0;
    while (y < self.size.y) : (y += 1) {
        // Start a new row div with flex layout
        try writer.print("<div class=\"row\" style=\"height:{d}px;\">\n", .{cell_height});

        var x: u32 = 0;
        while (x < self.size.x) : (x += 1) {
            const cell = self.fetchCell(.{ .x = x, .y = y });
            const r_bg, const g_bg, const b_bg = cell.bg.toU8RGB();
            const r_fg, const g_fg, const b_fg = cell.fg.toU8RGB();

            // Start building the cell style with flex item properties
            try writer.print("<span class=\"cell\" style=\"width:{d}px;height:{d}px;flex-basis:{d}px;line-height:{d}px;", .{ cell_width, cell_height, cell_width, cell_height });

            // Set background color
            try writer.print("background-color:rgb({d},{d},{d});", .{ r_bg, g_bg, b_bg });

            // Set text color
            try writer.print("color:rgb({d},{d},{d});", .{ r_fg, g_fg, b_fg });

            // Text formatting
            if (cell.formatting.is_bold) {
                try writer.writeAll("font-weight:bold;");
            }
            if (cell.formatting.is_italic) {
                try writer.writeAll("font-style:italic;");
            }
            if (cell.formatting.is_dim) {
                try writer.writeAll("opacity:0.7;");
            }

            // Text decorations
            switch (cell.formatting.decoration_line) {
                .underline => try writer.writeAll("text-decoration:underline;"),
                .double => try writer.writeAll("text-decoration:underline;text-decoration-style:double;"),
                .dashed => try writer.writeAll("text-decoration:underline;text-decoration-style:dashed;"),
                .wavy => try writer.writeAll("text-decoration:underline;text-decoration-style:wavy;"),
                .line_through => try writer.writeAll("text-decoration:line-through;"),
                else => {}, // No decoration
            }

            // If there's a decoration color
            if (cell.formatting.decoration_color) |dec_color| {
                const dr, const dg, const db = dec_color.toU8RGB();
                try writer.print("text-decoration-color:rgb({d},{d},{d});", .{ dr, dg, db });
            }

            // Close the style attribute
            try writer.writeAll("\"");

            // Add data attributes for character information
            if (cell.chars.len > 0) {
                try writer.writeAll(" data-chars=\"");
                for (cell.chars) |c| {
                    try writer.print("{d} ", .{c});
                }
                try writer.writeAll("\"");
            }

            try writer.writeAll(">");

            // Add the actual text content
            if (cell.chars.len > 0) {
                // Escape HTML special characters
                for (cell.chars) |c| {
                    switch (c) {
                        '<' => try writer.writeAll("&lt;"),
                        '>' => try writer.writeAll("&gt;"),
                        '&' => try writer.writeAll("&amp;"),
                        '"' => try writer.writeAll("&quot;"),
                        '\'' => try writer.writeAll("&#39;"),
                        else => try writer.writeByte(c),
                    }
                }
            } else {
                try writer.writeAll("&nbsp;");
            }

            // Close the span
            try writer.writeAll("</span>");
        }

        // End the row
        try writer.writeAll("</div>\n");
    }

    try writer.writeAll("</div>\n");

    // Add container for cell details
    try writer.writeAll("<div id=\"cell-details\"></div>\n");

    // Add JavaScript for handling cell clicks
    try writer.writeAll("<script>\n");
    try writer.writeAll(
        \\document.addEventListener('DOMContentLoaded', function() {
        \\  const cells = document.querySelectorAll('.cell');
        \\  const detailsEl = document.getElementById('cell-details');
        \\  let lastClickedCell = null;
        \\  
        \\  cells.forEach((cell) => {
        \\    // Show details on hover
        \\    cell.addEventListener('mouseenter', function() {
        \\      // Remove hover highlight from all cells
        \\      cells.forEach(c => c.classList.remove('cell-hover'));
        \\      
        \\      // Add hover highlight to current cell
        \\      if (cell !== lastClickedCell) {
        \\        cell.classList.add('cell-hover');
        \\      }
        \\      
        \\      showCellDetails(cell);
        \\    });
        \\    
        \\    // Revert to last clicked cell when hover ends
        \\    cell.addEventListener('mouseleave', function() {
        \\      // Remove hover highlight
        \\      cell.classList.remove('cell-hover');
        \\      
        \\      if (lastClickedCell) {
        \\        showCellDetails(lastClickedCell);
        \\      }
        \\    });
        \\    
        \\    // Remember last clicked cell
        \\    cell.addEventListener('click', function() {
        \\      // Remove highlight from all cells
        \\      cells.forEach(c => {
        \\        c.classList.remove('cell-highlight');
        \\        c.classList.remove('cell-hover');
        \\      });
        \\      
        \\      // Add highlight to clicked cell
        \\      cell.classList.add('cell-highlight');
        \\      
        \\      lastClickedCell = cell;
        \\      showCellDetails(cell);
        \\    });
        \\  });
        \\  
        \\  // Function to show cell details
        \\  function showCellDetails(cell) {
        \\    const styles = window.getComputedStyle(cell);
        \\    const pos = getCellPosition(cell);
        \\    
        \\    let details = `Cell Information:\n`;
        \\    details += `Position: Row ${pos.row}, Column ${pos.col}\n`;
        \\    details += `Content: "${cell.textContent || '(empty)'}"\\n`;
        \\    
        \\    // Add character codes if available
        \\    const charCodes = cell.getAttribute('data-chars');
        \\    if (charCodes) {
        \\      const codes = charCodes.trim().split(' ').filter(c => c);
        \\      details += `Character Codes: ${codes.join(', ')}\n`;
        \\      details += `UTF-8 Characters: ${codes.map(c => String.fromCharCode(parseInt(c))).join('')}\n`;
        \\    }
        \\    
        \\    details += `Dimensions: ${styles.width} × ${styles.height}\n`;
        \\    details += `Background: ${styles.backgroundColor}\n`;
        \\    details += `Text Color: ${styles.color}\n`;
        \\    
        \\    // Check for formatting
        \\    const formatting = [];
        \\    if (styles.fontWeight !== '400') formatting.push(`Bold (${styles.fontWeight})`);
        \\    if (styles.fontStyle !== 'normal') formatting.push(styles.fontStyle);
        \\    if (styles.opacity !== '1') formatting.push(`Dim (opacity: ${styles.opacity})`);
        \\    if (styles.textDecoration !== 'none') formatting.push(`Decoration: ${styles.textDecoration}`);
        \\    
        \\    if (formatting.length > 0) {
        \\      details += `Formatting: ${formatting.join(', ')}\n`;
        \\    }
        \\    
        \\    // Add info about current selection
        \\    details += `\n${cell === lastClickedCell ? '[Locked selection]' : '[Hover - click to lock]'}`;
        \\    details += `\n[Click outside cells to close]`;
        \\    
        \\    detailsEl.textContent = details;
        \\    detailsEl.style.display = 'block';
        \\  }
        \\  
        \\  // Click anywhere to close details
        \\  document.addEventListener('click', function(e) {
        \\    if (e.target.closest('.cell')) return; // Don't close when clicking cells
        \\    detailsEl.style.display = 'none';
        \\    lastClickedCell = null; // Reset last clicked cell
        \\    
        \\    // Clear all highlights
        \\    cells.forEach(c => {
        \\      c.classList.remove('cell-highlight');
        \\      c.classList.remove('cell-hover');
        \\    });
        \\  });
        \\  
        \\  function getCellPosition(cell) {
        \\    const row = cell.closest('.row');
        \\    const rowIndex = Array.from(row.parentNode.children).indexOf(row);
        \\    const colIndex = Array.from(row.children).indexOf(cell);
        \\    return { row: rowIndex, col: colIndex };
        \\  }
        \\});
    );
    try writer.writeAll("</script>\n");

    try writer.writeAll("</body>\n");
    try writer.writeAll("</html>\n");
}

fn isPowerline(char: u21) bool {
    return switch (char) {
        0xE0B0...0xE0C8, 0xE0CA, 0xE0CC...0xE0D2, 0xE0D4 => true,
        else => false,
    };
}

// test "text_formatting_simple" {
//     var canvas = try init(
//         std.testing.allocator,
//         .{ .x = 80, .y = 40 },
//         Color.tw.black,
//         Color.tw.white,
//     );
//     defer canvas.deinit();

//     // Basic string rendering test
//     try canvas.drawString(.{ .x = 5, .y = 2 }, "Regular text", Color.tw.white);

//     // Test with bold formatting
//     const bold_format = TextFormat{
//         .is_bold = true,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 4 }, "Bold text", Color.tw.white, bold_format);

//     // Test with italic formatting
//     const italic_format = TextFormat{
//         .is_italic = true,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 6 }, "Italic text", Color.tw.white, italic_format);

//     // Test with dim formatting
//     const dim_format = TextFormat{
//         .is_dim = true,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 8 }, "Dim text", Color.tw.white, dim_format);

//     // Test with underline
//     const underline_format = TextFormat{
//         .decoration_line = .underline,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 10 }, "Underlined text", Color.tw.white, underline_format);

//     // Test with strikethrough
//     const strikethrough_format = TextFormat{
//         .decoration_line = .line_through,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 12 }, "Strikethrough text", Color.tw.white, strikethrough_format);

//     // Test with wavy/squiggle underline (for errors)
//     const wavy_format = TextFormat{
//         .decoration_line = .wavy,
//         .decoration_color = Color.tw.red_500,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 14 }, "Text with error", Color.tw.white, wavy_format);

//     // Test combined formatting
//     const combined_format = TextFormat{
//         .is_bold = true,
//         .decoration_line = .underline,
//         .decoration_color = Color.tw.cyan_400,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 16 }, "Bold and underlined", Color.tw.white, combined_format);

//     // Test format reset
//     try canvas.drawString(.{ .x = 5, .y = 18 }, "Back to normal", Color.tw.white);

//     // Render to verify (this won't actually display in tests, but ensures the code runs)
//     const dev_null = std.io.getStdErr().writer().any();
//     try canvas.render(dev_null, false);

//     // Check that format is stored in cells
//     {
//         const cell = canvas.fetchCell(.{ .x = 5, .y = 4 });
//         try std.testing.expect(cell.formatting.is_bold);
//         try std.testing.expect(!cell.formatting.is_italic);
//     }

//     {
//         const cell = canvas.fetchCell(.{ .x = 5, .y = 10 });
//         try std.testing.expectEqual(cell.formatting.decoration_line, .underline);
//     }

//     {
//         const cell = canvas.fetchCell(.{ .x = 5, .y = 14 });
//         try std.testing.expectEqual(cell.formatting.decoration_line, .wavy);
//         try std.testing.expect(cell.formatting.decoration_color != null);
//     }
// }

// test "canvas" {
//     var canvas = try init(
//         std.testing.allocator,
//         .{ .x = 100, .y = 250 },
//         Color.tw.black,
//         Color.tw.white,
//     );
//     defer canvas.deinit();

//     // Demonstrate gradients
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     // Title
//     try canvas.drawString(.{ .x = 35, .y = 1 }, "Gradient Rendering Demo", Color.tw.cyan_500);

//     // Linear gradients examples
//     try canvas.drawString(.{ .x = 2, .y = 3 }, "Linear Gradients:", Color.tw.green_500);

//     const horizontal_gradient = "linear-gradient(to right, red, yellow, green, cyan, blue)";
//     const horizontal_result = styles.background.parse(allocator, horizontal_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 5 }, "Horizontal:", null);
//     try canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 5 }, .size = .{ .x = 70, .y = 3 } }, horizontal_result.value);

//     const vertical_gradient = "linear-gradient(to bottom, red, yellow, green, blue)";
//     const vertical_result = styles.background.parse(allocator, vertical_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 9 }, "Vertical:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 9 }, .size = .{ .x = 20, .y = 8 } }, vertical_result.value);

//     const diagonal_gradient = "linear-gradient(45deg, red, blue)";
//     const diagonal_result = styles.background.parse(allocator, diagonal_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 45, .y = 9 }, "Diagonal:", null);
//     try canvas.drawRectBg(.{ .pos = .{ .x = 60, .y = 9 }, .size = .{ .x = 20, .y = 8 } }, diagonal_result.value);

//     // Complex example with percentage stops
//     const complex_gradient = "linear-gradient(to right, red, yellow 30%, green 70%, blue)";
//     const complex_result = styles.background.parse(allocator, complex_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 18 }, "With % stops:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 18 }, .size = .{ .x = 70, .y = 3 } }, complex_result.value);

//     // Radial gradients examples
//     try canvas.drawString(.{ .x = 2, .y = 22 }, "Radial Gradients:", Color.tw.green_500);

//     // Basic radial gradients
//     const circle_gradient = "radial-gradient(circle at center, red, yellow, blue)";
//     const circle_result = styles.background.parse(allocator, circle_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 24 }, "Circle:", null);
//     try canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 24 }, .size = .{ .x = 20, .y = 5 } }, circle_result.value);

//     const ellipse_gradient = "radial-gradient(ellipse at center, red, yellow, blue)";
//     const ellipse_result = styles.background.parse(allocator, ellipse_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 45, .y = 24 }, "Ellipse:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 60, .y = 24 }, .size = .{ .x = 35, .y = 5 } }, ellipse_result.value);

//     // Radial gradients with different sizes
//     try canvas.drawString(.{ .x = 2, .y = 30 }, "Radial Sizes:", Color.tw.blue_500);

//     const closest_side = "radial-gradient(circle closest-side at center, red, yellow, blue)";
//     const closest_side_result = styles.background.parse(allocator, closest_side, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 32 }, "Closest-side:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 32 }, .size = .{ .x = 20, .y = 5 } }, closest_side_result.value);

//     const farthest_side = "radial-gradient(circle farthest-side at center, red, yellow, blue)";
//     const farthest_side_result = styles.background.parse(allocator, farthest_side, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 45, .y = 32 }, "Farthest-side:", null);
//     try canvas.drawRectBg(.{ .pos = .{ .x = 65, .y = 32 }, .size = .{ .x = 20, .y = 5 } }, farthest_side_result.value);

//     // Radial gradients with different positions
//     try canvas.drawString(.{ .x = 2, .y = 38 }, "Radial Positions:", Color.tw.blue_500);

//     const top_left = "radial-gradient(circle at top left, red, yellow, blue)";
//     const top_left_result = styles.background.parse(allocator, top_left, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 40 }, "Top-left:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 40 }, .size = .{ .x = 20, .y = 5 } }, top_left_result.value);

//     const custom_pos = "radial-gradient(circle at 75% 25%, red, yellow, blue)";
//     const custom_pos_result = styles.background.parse(allocator, custom_pos, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 45, .y = 40 }, "Custom (75%, 25%):", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 70, .y = 40 }, .size = .{ .x = 20, .y = 5 } }, custom_pos_result.value);

//     // Radial gradients with percentage stops
//     try canvas.drawString(.{ .x = 2, .y = 46 }, "Complex Radials:", Color.tw.blue_500);

//     const circle_stops = "radial-gradient(circle, red, yellow 30%, green 60%, blue)";
//     const circle_stops_result = styles.background.parse(allocator, circle_stops, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 48 }, "With % stops:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 20, .y = 48 }, .size = .{ .x = 20, .y = 5 } }, circle_stops_result.value);

//     const ellipse_corner = "radial-gradient(ellipse at bottom right, red, yellow, blue)";
//     const ellipse_corner_result = styles.background.parse(allocator, ellipse_corner, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 45, .y = 48 }, "Bottom-right:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 70, .y = 48 }, .size = .{ .x = 20, .y = 5 } }, ellipse_corner_result.value);

//     // Extra complex case
//     const explicit_size = "radial-gradient(ellipse farthest-corner at 20% 80%, red, yellow 10%, green 50%, blue 90%)";
//     const explicit_size_result = styles.background.parse(allocator, explicit_size, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 54 }, "Explicit size & pos:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 54 }, .size = .{ .x = 65, .y = 5 } }, explicit_size_result.value);

//     // The requested test case
//     const right_edge_gradient = "radial-gradient(circle at 100%, gray, gray 50%, white 75%, gray 75%)";
//     const right_edge_result = styles.background.parse(allocator, right_edge_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 60 }, "Edge with ring:", null);
//     canvas.setAntiAliasingSamples(1); // No anti-aliasing
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 60 }, .size = .{ .x = 65, .y = 15 } }, right_edge_result.value);

//     try canvas.drawString(.{ .x = 5, .y = 76 }, "Same with AA (8x):", null);
//     canvas.setAntiAliasingSamples(8); // High anti-aliasing
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 76 }, .size = .{ .x = 65, .y = 15 } }, right_edge_result.value);

//     // Anti-aliasing examples
//     try canvas.drawString(.{ .x = 2, .y = 71 }, "When Anti-Aliasing Matters:", Color.tw.green_500);
//     try canvas.drawString(.{ .x = 2, .y = 73 }, "(Diagonal gradients, edge transitions, non-centered radial)", Color.tw.green_300);

//     // Test with diagonal gradient where anti-aliasing matters
//     const diagonal_aa_gradient = "linear-gradient(45deg, red, blue)";
//     const diagonal_aa_result = styles.background.parse(allocator, diagonal_aa_gradient, 0) catch unreachable;

//     try canvas.drawString(.{ .x = 5, .y = 75 }, "Diagonal Gradient:", Color.tw.blue_500);

//     // No anti-aliasing (1 sample)
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 77 }, "1x1 (none):", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 77 }, .size = .{ .x = 35, .y = 8 } }, diagonal_aa_result.value);

//     // 4x4 = 16 samples (default)
//     canvas.setAntiAliasingSamples(4);
//     try canvas.drawString(.{ .x = 5, .y = 86 }, "4x4 (16 samples):", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 86 }, .size = .{ .x = 35, .y = 8 } }, diagonal_aa_result.value);

//     // 8x8 = 64 samples (high quality)
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 95 }, "8x8 (64 samples):", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 95 }, .size = .{ .x = 35, .y = 8 } }, diagonal_aa_result.value);

//     // Test with radial gradient where anti-aliasing matters most
//     const radial_aa_gradient = "radial-gradient(circle at center, red, blue)";
//     const radial_aa_result = styles.background.parse(allocator, radial_aa_gradient, 0) catch unreachable;

//     try canvas.drawString(.{ .x = 5, .y = 104 }, "Radial Gradient:", Color.tw.blue_500);

//     // No anti-aliasing
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 106 }, "No AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 106 }, .size = .{ .x = 35, .y = 8 } }, radial_aa_result.value);

//     // Medium anti-aliasing
//     canvas.setAntiAliasingSamples(4);
//     try canvas.drawString(.{ .x = 5, .y = 115 }, "Medium AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 115 }, .size = .{ .x = 35, .y = 8 } }, radial_aa_result.value);

//     // High anti-aliasing
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 124 }, "High AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 124 }, .size = .{ .x = 35, .y = 8 } }, radial_aa_result.value);

//     // Compare vertical gradient with and without anti-aliasing (should look the same)
//     const vertical_aa_gradient = "linear-gradient(to bottom, red, blue)";
//     const vertical_aa_result = styles.background.parse(allocator, vertical_aa_gradient, 0) catch unreachable;

//     try canvas.drawString(.{ .x = 5, .y = 133 }, "Vertical Gradient (no difference):", Color.tw.blue_500);

//     // No anti-aliasing
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 135 }, "No AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 135 }, .size = .{ .x = 35, .y = 8 } }, vertical_aa_result.value);

//     // With anti-aliasing (should look the same as without)
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 144 }, "High AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 144 }, .size = .{ .x = 35, .y = 8 } }, vertical_aa_result.value);

//     // Anti-aliasing examples where the difference is clearly visible
//     try canvas.drawString(.{ .x = 2, .y = 154 }, "Situations Where AA Makes a Big Difference:", Color.tw.green_500);
//     try canvas.drawString(.{ .x = 2, .y = 156 }, "(Use AA=8 for these cases)", Color.tw.green_300);

//     // Sharp transition case - clear difference with anti-aliasing
//     const sharp_transition = "linear-gradient(45deg, red 50%, blue 50%)";
//     const sharp_transition_result = styles.background.parse(allocator, sharp_transition, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 158 }, "Sharp Diagonal Transition:", Color.tw.blue_500);

//     // No anti-aliasing
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 158 }, "No AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 158 }, .size = .{ .x = 35, .y = 8 } }, sharp_transition_result.value);

//     // High anti-aliasing
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 167 }, "High AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 167 }, .size = .{ .x = 35, .y = 8 } }, sharp_transition_result.value);

//     // Offset radial gradient with sharp ring - another case where AA matters
//     const offset_radial_ring = "radial-gradient(circle at 25% 25%, red, red 30%, blue 30%, blue 60%, yellow 60%)";
//     const offset_radial_ring_result = styles.background.parse(allocator, offset_radial_ring, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 176 }, "Offset Radial Rings:", Color.tw.blue_500);

//     // No anti-aliasing
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 178 }, "No AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 178 }, .size = .{ .x = 35, .y = 8 } }, offset_radial_ring_result.value);

//     // High anti-aliasing
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 187 }, "High AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 187 }, .size = .{ .x = 35, .y = 8 } }, offset_radial_ring_result.value);

//     // Elliptical gradient with sharp rings - shows AA importance with non-circular shapes
//     const elliptical_rings = "radial-gradient(ellipse at center, red, red 25%, green 25%, green 50%, blue 50%, blue 75%, yellow 75%)";
//     const elliptical_rings_result = styles.background.parse(allocator, elliptical_rings, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 196 }, "Elliptical Sharp Rings:", Color.tw.blue_500);

//     // No anti-aliasing
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 198 }, "No AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 198 }, .size = .{ .x = 45, .y = 15 } }, elliptical_rings_result.value);

//     // High anti-aliasing
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 214 }, "High AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 214 }, .size = .{ .x = 45, .y = 15 } }, elliptical_rings_result.value);

//     // Extreme case - diagonal with multiple sharp transitions
//     const multi_diagonal = "linear-gradient(45deg, red 20%, blue 20%, blue 40%, green 40%, green 60%, yellow 60%, yellow 80%, purple 80%)";
//     const multi_diagonal_result = styles.background.parse(allocator, multi_diagonal, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 5, .y = 230 }, "Multi-Stop Diagonal:", Color.tw.blue_500);

//     // No anti-aliasing
//     canvas.setAntiAliasingSamples(1);
//     try canvas.drawString(.{ .x = 5, .y = 232 }, "No AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 232 }, .size = .{ .x = 45, .y = 8 } }, multi_diagonal_result.value);

//     // High anti-aliasing
//     canvas.setAntiAliasingSamples(8);
//     try canvas.drawString(.{ .x = 5, .y = 241 }, "High AA:", null);
//     canvas.drawRectBg(.{ .pos = .{ .x = 25, .y = 241 }, .size = .{ .x = 45, .y = 8 } }, multi_diagonal_result.value);

//     const writer = std.io.getStdErr().writer().any();
//     try canvas.render(writer);
// }

// // Add a function to set anti-aliasing samples
// pub fn setAntiAliasingSamples(self: *Self, samples: u32) void {
//     self.anti_aliasing_samples = @max(1, samples); // Ensure at least 1 sample
// }

// // Add a new test for performance measurement with animated gradients
// // ... existing code ...

// // ... existing code ...

// test "gradient_angles" {
//     // var gradient_type: u8 = 0; // 0: linear, 1: radial
//     // _ = gradient_type; // autofix

//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     var canvas = try init(
//         allocator,
//         .{ .x = 100, .y = 200 }, // Larger canvas size
//         Color.tw.black,
//         Color.tw.white,
//     );
//     defer canvas.deinit();
//     var y: u32 = 0;
//     {
//         var angle: f32 = 0.0;
//         var linear_angle_result = styles.background.parse(allocator, "linear-gradient(0deg, red, blue)", 0) catch unreachable;
//         while (angle < 360) : (angle += 15) {
//             linear_angle_result.value.linear_gradient.angle = angle;
//             // canvas.drawRectBg(.{ .pos = .{ .x = x, .y = 9 }, .size = .{ .x = 20, .y = 8 } }, angle_result.value);
//             // try canvas.drawString(.{ .x = 5, .y = 5 }, "Gradient Angle:", Color.tw.green_500);
//             // try canvas.drawString(.{ .x = 5, .y = 9 }, "Angle:", null);
//             canvas.drawRectBg(.{ .pos = .{ .x = 0, .y = y }, .size = .{ .x = 20, .y = 6 } }, linear_angle_result.value);
//             const angle_str = try std.fmt.allocPrint(allocator, "Angle: {d}", .{angle});
//             try canvas.drawString(.{ .x = 25, .y = y }, angle_str, null);
//             y += 7;
//         }
//     }

//     // {
//     //     var angle: f32 = 0.0;
//     //     var radial_angle_result = styles.background.parse(allocator, "radial-gradient(circle at center, red, blue)", 0) catch unreachable;
//     //     while (angle < 360) : (angle += 15) {
//     //         radial_angle_result.value.radial_gradient.position.x = .{ .length = angle };
//     //         canvas.drawRectBg(.{ .pos = .{ .x = 0, .y = y }, .size = .{ .x = 20, .y = 6 } }, radial_angle_result.value);
//     //         const angle_str = try std.fmt.allocPrint(allocator, "Angle: {d}", .{angle});
//     //         try canvas.drawString(.{ .x = 25, .y = y }, angle_str, null);
//     //         y += 7;
//     //     }
//     // }
//     // try canvas.render(std.io.getStdErr().writer().any());
// }

// test "render_to_html" {
//     var canvas = try init(
//         std.testing.allocator,
//         .{ .x = 20, .y = 5 },
//         Color.tw.black,
//         Color.tw.white,
//     );
//     defer canvas.deinit();

//     // Initialize the canvas
//     try canvas.clear();

//     // Add simple content
//     try canvas.drawString(.{ .x = 1, .y = 1 }, "Test", Color.tw.cyan_500);

//     // Format a cell
//     const bold_format = TextFormat{
//         .is_bold = true,
//     };
//     try canvas.drawStringFormatted(.{ .x = 1, .y = 3 }, "Bold", Color.tw.white, bold_format);

//     // Render to a buffer
//     var buffer = std.ArrayList(u8).init(std.testing.allocator);
//     defer buffer.deinit();
//     try canvas.renderToHtml(buffer.writer().any());

//     // Verify the buffer has reasonable content
//     const html = buffer.items;
//     try std.testing.expect(html.len > 500);
//     try std.testing.expect(html.len < 100000);

//     // Print the output size
//     std.debug.print("HTML output size: {d} bytes\n", .{html.len});

//     // Save the HTML to the test_snapshots directory
//     const file_path = "test_snapshots/canvas_basic_test.html";
//     try canvas.saveAsHtml(file_path);
//     std.debug.print("Saved HTML output to {s}\n", .{file_path});
// }

// test "render_to_html_with_gradients" {
//     var canvas = try init(
//         std.testing.allocator,
//         .{ .x = 40, .y = 10 }, // Larger canvas for better gradient visibility
//         Color.tw.black,
//         Color.tw.white,
//     );
//     defer canvas.deinit();

//     // Initialize the canvas
//     try canvas.clear();

//     // Setup an arena allocator for gradients
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     // Add a heading
//     const heading_format = TextFormat{
//         .is_bold = true,
//         .decoration_line = .underline,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 1 }, "Gradient Demo", Color.tw.white, heading_format);

//     // Add a horizontal linear gradient
//     const h_gradient = "linear-gradient(to right, red, yellow, blue)";
//     const h_gradient_result = styles.background.parse(allocator, h_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 2, .y = 3 }, "Horizontal:", Color.tw.white);
//     try canvas.drawRectBg(Rect.init(13, 3, 25, 1), h_gradient_result.value);

//     // Add a vertical linear gradient
//     const v_gradient = "linear-gradient(to bottom, green, cyan)";
//     const v_gradient_result = styles.background.parse(allocator, v_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 2, .y = 5 }, "Vertical:", Color.tw.white);
//     try canvas.drawRectBg(Rect.init(13, 5, 10, 3), v_gradient_result.value);

//     // Add a radial gradient
//     const radial_gradient = "radial-gradient(circle at center, magenta, gold, teal)";
//     const radial_result = styles.background.parse(allocator, radial_gradient, 0) catch unreachable;
//     try canvas.drawString(.{ .x = 25, .y = 5 }, "Radial:", Color.tw.white);
//     try canvas.drawRectBg(Rect.init(25, 6, 10, 3), radial_result.value);

//     // Render to a buffer
//     var buffer = std.ArrayList(u8).init(std.testing.allocator);
//     defer buffer.deinit();
//     try canvas.renderToHtml(buffer.writer().any());

//     // Verify the buffer has reasonable content
//     const html = buffer.items;
//     try std.testing.expect(html.len > 500);
//     try std.testing.expect(html.len < 100000);

//     // Print the output size
//     std.debug.print("Gradient HTML output size: {d} bytes\n", .{html.len});

//     // Save the HTML to the test_snapshots directory
//     const file_path = "test_snapshots/canvas_gradient_test.html";
//     try canvas.saveAsHtml(file_path);
//     std.debug.print("Saved HTML output to {s}\n", .{file_path});
// }

// test "render_to_html_showcase" {
//     var canvas = try init(
//         std.testing.allocator,
//         .{ .x = 80, .y = 20 },
//         Color.tw.gray_900,
//         Color.tw.white,
//     );
//     defer canvas.deinit();

//     // Initialize the canvas
//     try canvas.clear();

//     // Setup an arena allocator for gradients
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     // Create a fancy background with multiple gradients

//     // Top section - rainbow gradient
//     const rainbow = "linear-gradient(to right, red, orange, yellow, green, blue, indigo, violet)";
//     const rainbow_result = styles.background.parse(allocator, rainbow, 0) catch unreachable;
//     try canvas.drawRectBg(Rect.init(0, 0, 80, 5), rainbow_result.value);

//     // Middle section - radial gradient
//     const radial = "radial-gradient(circle at center, #fff, #aaa 40%, #333 80%)";
//     const radial_result = styles.background.parse(allocator, radial, 0) catch unreachable;
//     try canvas.drawRectBg(Rect.init(20, 6, 40, 8), radial_result.value);

//     // Bottom section - diagonal gradient
//     const diagonal = "linear-gradient(45deg, #0074D9, #7FDBFF)";
//     const diagonal_result = styles.background.parse(allocator, diagonal, 0) catch unreachable;
//     try canvas.drawRectBg(Rect.init(0, 15, 80, 5), diagonal_result.value);

//     // Add a title with fancy formatting
//     const title_format = TextFormat{
//         .is_bold = true,
//         .decoration_line = .underline,
//         .decoration_color = Color.tw.yellow_400,
//     };
//     try canvas.drawStringFormatted(.{ .x = 25, .y = 2 }, "Canvas HTML Renderer", Color.tw.black, title_format);

//     // Add styled text samples
//     const bold_format = TextFormat{
//         .is_bold = true,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 7 }, "Bold Text Sample", Color.tw.red_500, bold_format);

//     const italic_format = TextFormat{
//         .is_italic = true,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 9 }, "Italic Text Sample", Color.tw.green_500, italic_format);

//     const strikethrough_format = TextFormat{
//         .decoration_line = .line_through,
//         .decoration_color = Color.tw.red_300,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 11 }, "Strikethrough Text", Color.tw.blue_500, strikethrough_format);

//     const wavy_format = TextFormat{
//         .decoration_line = .wavy,
//         .decoration_color = Color.tw.orange_500,
//     };
//     try canvas.drawStringFormatted(.{ .x = 5, .y = 13 }, "Wavy Underline Text", Color.tw.purple_500, wavy_format);

//     // Add a combined format text over the diagonal gradient
//     const combined_format = TextFormat{
//         .is_bold = true,
//         .is_italic = true,
//         .decoration_line = .underline,
//         .decoration_color = Color.tw.white,
//     };
//     try canvas.drawStringFormatted(.{ .x = 25, .y = 17 }, "Combined Formatting", Color.tw.white, combined_format);

//     // Render to a buffer
//     var buffer = std.ArrayList(u8).init(std.testing.allocator);
//     defer buffer.deinit();
//     try canvas.renderToHtml(buffer.writer().any());

//     // Verify the buffer has reasonable content
//     const html = buffer.items;
//     try std.testing.expect(html.len > 1000);
//     try std.testing.expect(html.len < 500000);

//     // Print the output size
//     std.debug.print("Showcase HTML output size: {d} bytes\n", .{html.len});

//     // Save the HTML to the test_snapshots directory
//     const file_path = "test_snapshots/canvas_showcase.html";
//     try canvas.saveAsHtml(file_path);
//     std.debug.print("Saved showcase HTML output to {s}\n", .{file_path});
// }

// test "wide_character_rendering" {
//     var canvas = try init(
//         std.testing.allocator,
//         .{ .x = 40, .y = 20 },
//         Color.tw.gray_900,
//         Color.tw.white,
//     );
//     defer canvas.deinit();

//     // Initialize the canvas
//     try canvas.clear();

//     // Add a title
//     const title_format = TextFormat{
//         .is_bold = true,
//         .decoration_line = .underline,
//     };
//     try canvas.drawStringFormatted(.{ .x = 6, .y = 1 }, "Wide Character Rendering Test", Color.tw.cyan_400, title_format);

//     // 1. Basic ASCII characters (for comparison)
//     try canvas.drawString(.{ .x = 2, .y = 3 }, "ASCII (width=1):", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 3 }, "abcdef", Color.tw.white);

//     // 2. Emojis (typically width=2)
//     try canvas.drawString(.{ .x = 2, .y = 5 }, "Emojis (width=2):", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 5 }, "😀🚀🎉", Color.tw.white);

//     // 3. CJK characters (typically width=2)
//     try canvas.drawString(.{ .x = 2, .y = 7 }, "CJK (width=2):", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 7 }, "你好世界", Color.tw.white); // "Hello World" in Chinese

//     // 4. Mixed width characters
//     try canvas.drawString(.{ .x = 2, .y = 9 }, "Mixed widths:", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 9 }, "a文b字c語", Color.tw.white);

//     // 5. Various symbols that might have different widths
//     try canvas.drawString(.{ .x = 2, .y = 11 }, "Symbols:", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 11 }, "♠♥♦♣★☆", Color.tw.white);

//     // 6. Combining characters
//     try canvas.drawString(.{ .x = 2, .y = 13 }, "Combining chars:", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 13 }, "e\u{0301} a\u{0308} n\u{0303}", Color.tw.white); // é ä ñ with combining marks

//     // 7. Different emoji styles
//     try canvas.drawString(.{ .x = 2, .y = 15 }, "Emoji variants:", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 15 }, "👨‍👩‍👧‍👦 👨‍💻 🏳️‍🌈", Color.tw.white); // Family, technologist, rainbow flag

//     // 8. Emoji with skin tones
//     try canvas.drawString(.{ .x = 2, .y = 17 }, "Skin tones:", Color.tw.green_400);
//     try canvas.drawString(.{ .x = 20, .y = 17 }, "👍 👍🏻 👍🏿", Color.tw.white); // Thumbs up with different skin tones

//     // Save the HTML to the test_snapshots directory
//     const file_path = "test_snapshots/canvas_wide_chars.html";
//     try canvas.saveAsHtml(file_path);
//     std.debug.print("Saved wide character test to {s}\n", .{file_path});
// }

/// Save canvas as HTML to a file
pub fn saveAsHtml(self: *Self, filepath: []const u8) !void {
    // Create directory if it doesn't exist
    const dir_path = std.fs.path.dirname(filepath) orelse "";
    if (dir_path.len > 0) {
        std.fs.cwd().makePath(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
            // Path already exists is fine, continue
        };
    }

    // Create and write to the file
    var file = try std.fs.cwd().createFile(filepath, .{});
    defer file.close();

    try self.renderToHtml(file.writer().any());
}
