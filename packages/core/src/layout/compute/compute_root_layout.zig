const std = @import("std");
const Point = @import("../point.zig").Point;
const Line = @import("../line.zig");
const Rect = @import("../rect.zig").Rect;
const Tree = @import("../tree/Tree.zig");
const Style = @import("../tree/Style.zig");
const ArrayList = std.ArrayList;
const Node = @import("../tree/Node.zig");
const NodeId = Node.NodeId;
const ComputeConstants = @import("compute_constants.zig");
const RunMode = ComputeConstants.RunMode;
const SizingMode = ComputeConstants.SizingMode;
const RequestedAxis = ComputeConstants.RequestedAxis;
const AvailableSpace = ComputeConstants.AvailableSpace;
const expect = std.testing.expect;

const compute_child_layout = @import("compute_child_layout.zig").compute_child_layout;

pub fn compute_root_layout(allocator: std.mem.Allocator, tree: *Tree, available_space: Point(AvailableSpace)) !void {
    // const root = tree.getNode(0);
    const layout = try compute_child_layout(allocator, 0, tree, .{
        .known_dimensions = Point(?f32).NULL,
        .parent_size = .{ .x = available_space.x.intoOption(), .y = available_space.y.intoOption() },
        .run_mode = RunMode.perform_layout,
        .available_space = available_space,
        .sizing_mode = SizingMode.inherent_size,
        .axis = RequestedAxis.Both,
        .vertical_margins_are_collapsible = Line.FALSE,
    });
    const style = tree.getComputedStyle(0);

    const maybe_width = available_space.width().intoOption();
    const padding = style.padding.maybeResolve(maybe_width).orZero();
    const border = style.border.maybeResolve(maybe_width).orZero();
    const scrollbar_size = Point(f32){
        .x = if (style.overflow.y == .scroll) style.scrollbar_width else 0.0,
        .y = if (style.overflow.x == .scroll) style.scrollbar_width else 0.0,
    };

    tree.setUnroundedLayout(0, .{
        .order = 0,
        .location = Point(f32).ZERO,
        .size = layout.size,
        .content_size = layout.content_size,
        .scrollbar_size = scrollbar_size,
        .padding = padding,
        .border = border,
    });
}
