const mod = @import("../mod.zig");
const LayoutNode = mod.LayoutNode;
const CSSMaybePoint = mod.CSSMaybePoint;
const css_types = @import("../../../css/types.zig");

l_node_id: LayoutNode.Id,
start: u32,
length: u32,
size: mod.CSSPoint,
is_atomic: bool,
