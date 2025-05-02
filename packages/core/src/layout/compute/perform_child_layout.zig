const std = @import("std");
const Node = @import("../tree/Node.zig");
const Tree = @import("../tree/Tree.zig");
const LayoutInput = @import("compute_constants.zig").LayoutInput;
const LayoutOutput = @import("compute_constants.zig").LayoutOutput;
const Point = @import("../point.zig").Point;
const Line = @import("../line.zig").Line;
const compute_constants = @import("compute_constants.zig");
const AvailableSpace = compute_constants.AvailableSpace;
const SizingMode = compute_constants.SizingMode;
const compute_child_layout = @import("compute_child_layout.zig").compute_child_layout;

const PerformChildLayoutError = error{
    FailedToPerformChildLayout,
    NodeNotFound,
};

pub fn perform_child_layout(
    allocator: std.mem.Allocator,
    node_id: Node.NodeId,
    tree: *Tree,
    known_dimensions: Point(?f32),
    parent_size: Point(?f32),
    available_space: Point(AvailableSpace),
    sizing_mode: SizingMode,
    vertical_margins_are_collapsible: Line(bool),
) PerformChildLayoutError!LayoutOutput {
    return compute_child_layout(
        allocator,
        node_id,
        tree,
        .{
            .known_dimensions = known_dimensions,
            .parent_size = parent_size,
            .available_space = available_space,
            .sizing_mode = sizing_mode,
            .axis = .Both,
            .run_mode = .perform_layout,
            .vertical_margins_are_collapsible = vertical_margins_are_collapsible,
        },
    ) catch error.FailedToPerformChildLayout;
}
