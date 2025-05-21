const std = @import("std");
const Node = @import("../../tree/Node.zig");
const Tree = @import("../../tree/Tree.zig");
const LayoutInput = @import("compute_constants.zig").LayoutInput;
const LayoutOutput = @import("compute_constants.zig").LayoutOutput;
const Point = @import("../point.zig").Point;
const Line = @import("../line.zig").Line;
const compute_constants = @import("compute_constants.zig");
const AvailableSpace = compute_constants.AvailableSpace;
const SizingMode = compute_constants.SizingMode;

const computeFlexboxLayout = @import("compute_flexbox_layout.zig").computeFlexboxLayout;
const computeLeafLayout = @import("compute_leaf_layout.zig").computeLeafLayout;
// const compute_line_breaks = @import("compute_line_breaks.zig").compute_line_breaks;
const computeBlockLayout = @import("compute_block_layout.zig").computeBlockLayout;
const computeTextLayout = @import("./text/compute-text-layout.zig").computeTextLayout;

fn Measurer() fn (known_dimensions: Point(?f32), available_space: Point(AvailableSpace)) Point(f32) {
    return struct {
        pub fn fun(known_dimensions: Point(?f32), available_space: Point(AvailableSpace)) Point(f32) {
            _ = known_dimensions; // autofix
            _ = available_space; // autofix
            // return .{
            //     .x = known_dimensions.x orelse switch (available_space.x) {
            //         .definite => |x| x,
            //         else => 0,
            //     },
            //     .y = known_dimensions.y orelse switch (available_space.y) {
            //         .definite => |y| y,
            //         else => 0,
            //     },
            // };

            return .{ .x = 0, .y = 0 };
        }
    }.fun;
}
pub fn getCachedLayout(node: *Node, inputs: LayoutInput) ?LayoutOutput {
    return node.cache.get(
        inputs.known_dimensions,
        inputs.available_space,
        inputs.run_mode,
    );
}
pub fn computeChildLayout(allocator: std.mem.Allocator, node_id: Node.NodeId, tree: *Tree, inputs: LayoutInput) !LayoutOutput {
    if (tree.getCache(node_id).get(
        inputs.known_dimensions,
        inputs.available_space,
        inputs.run_mode,
    )) |layout| {
        return layout;
    }

    const computed: LayoutOutput = blk: {
        const style = tree.getComputedStyle(node_id);
        const display = style.display;
        // if (tree.getChildren(node_id).items.len == 0 and style.display.inside != .flow) {
        if (display.isInlineFlow()) {
            break :blk try computeTextLayout(allocator, node_id, tree, inputs);
        }
        if (tree.getChildren(node_id).items.len == 0) {
            break :blk try computeLeafLayout(inputs, node_id, tree, Measurer());
        }

        // try compute_line_breaks(allocator, node);
        break :blk switch (display.outside) {
            // .flex => try computeFlexboxLayout(allocator, node, inputs),
            .block => switch (display.inside) {
                .flex => try computeFlexboxLayout(allocator, node_id, tree, inputs),
                .flow_root => try computeBlockLayout(allocator, node_id, tree, inputs),
                .flow => try computeBlockLayout(allocator, node_id, tree, inputs),
            },
            .@"inline" => switch (display.inside) {
                .flex => try computeFlexboxLayout(allocator, node_id, tree, inputs),
                .flow_root => try computeBlockLayout(allocator, node_id, tree, inputs),
                .flow => try computeBlockLayout(allocator, node_id, tree, inputs),
            },
            .none => return error.unimplemented,
        };
        // break :blk switch (node.styles.display) {
        //     .flex => try computeFlexboxLayout(allocator, node, inputs),
        //     .block => try computeBlockLayout(allocator, node, inputs),
        //     else => return error.unimplemented,
        // };
    };

    tree.getCache(node_id).store(
        inputs.known_dimensions,
        inputs.available_space,
        inputs.run_mode,
        computed,
    );

    return computed;
}

// pub fn computeTextLayout(allocator: std.mem.Allocator, node_id: Node.NodeId, tree: *Tree, inputs: LayoutInput) !LayoutOutput {
//     const node = tree.getNode(node_id);
//     try computeFlexboxLayout(allocator, node_id, tree, inputs);
//     return computeLeafLayout(inputs, node, Measurer());
// }
