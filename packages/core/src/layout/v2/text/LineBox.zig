const mod = @import("../mod.zig");
const LineBoxFragment = @import("./LineBoxFragment.zig");
const LayoutNode = mod.LayoutNode;
const css_types = @import("../../../css/types.zig");
const std = @import("std");
const ArrayList = std.ArrayList;

size: mod.CSSPoint,
fragments: ArrayList(LineBoxFragment),
available_width: f32,
