// const Node = @import("../../tree/Node.zig");
// const Tree = @import("../../tree/Tree.zig");
// const Point = @import("../point.zig").Point;
// const Line = @import("../line.zig").Line;
// const constants = @import("compute_constants.zig");
// const AvailableSpace = constants.AvailableSpace;
// const SizingMode = constants.SizingMode;
// const AbsoluteAxis = constants.AbsoluteAxis;
// const computeChildLayout = @import("computeChildLayout.zig").computeChildLayout;
const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
const MeasureChildError = error{
    FailedToComputeChildLayout,
};

const std = @import("std");

pub fn measureChildSize(
    context: *mod.LayoutContext,
    node_id: mod.LayoutNode.Id,
    known_dimensions: mod.CSSMaybePoint,
    parent_size: mod.CSSMaybePoint,
    available_space: mod.constants.AvailableSpacePoint,
    sizing_mode: mod.constants.SizingMode,
    axis: mod.constants.RequestedAxis,
    vertical_margins_are_collapsible: mod.Line(bool),
) MeasureChildError!f32 {
    const child_layout = try mod.computeLayout(
        context,
        available_space,
        node_id,
        .{
            .known_dimensions = known_dimensions,
            .parent_size = parent_size,
            .available_space = available_space,
            .sizing_mode = sizing_mode,
            .axis = axis.toRequestedAxis(),
            .run_mode = .compute_size,
            .vertical_margins_are_collapsible = vertical_margins_are_collapsible,
        },
    ) catch return error.FailedToComputeChildLayout;

    return axis.getAxis(child_layout.size);
}
