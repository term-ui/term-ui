const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;
const LayoutNode = mod.LayoutNode;

available_space: AvailableSpacePoint,
compute_mode: ComputeMode,

pub const ComputeMode = enum {
    size,
    layout,
};

pub const AvailableSpace = union(enum) {
    definite: f32,
    min_content,
    max_content,
};

pub const AvailableSpacePoint = mod.PointOf(AvailableSpace);
