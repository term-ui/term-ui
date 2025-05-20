const Node = @import("../tree/Node.zig");
const Tree = @import("../tree/Tree.zig");
const Point = @import("../point.zig").Point;
const Line = @import("../line.zig").Line;
const constants = @import("compute_constants.zig");
const AvailableSpace = constants.AvailableSpace;
const SizingMode = constants.SizingMode;
const AbsoluteAxis = constants.AbsoluteAxis;
const computeChildLayout = @import("compute_child_layout.zig").computeChildLayout;
const MeasureChildError = error{
    FailedToComputeChildLayout,
};

const std = @import("std");

pub fn measureChildSize(
    allocator: std.mem.Allocator,
    node_id: Node.NodeId,
    tree: *Tree,
    known_dimensions: Point(?f32),
    parent_size: Point(?f32),
    available_space: Point(AvailableSpace),
    sizing_mode: SizingMode,
    axis: AbsoluteAxis,
    vertical_margins_are_collapsible: Line(bool),
) MeasureChildError!f32 {
    const child_layout = computeChildLayout(
        allocator,
        node_id,
        tree,
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
