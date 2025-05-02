const Node = @import("../tree/Node.zig");
const Tree = @import("../tree/Tree.zig");
const Point = @import("../point.zig").Point;

const std = @import("std");

fn round(value: anytype, comptime decimal_places: f32) @TypeOf(value) {
    if (comptime decimal_places == 0) {
        return @round(value);
    }
    const factor = comptime std.math.pow(@TypeOf(value), 10.0, decimal_places);
    return @round(value * factor) / factor;
}

// fn round_inner(node_id: Node.NodeId, tree: *Tree, cumulative: Point(f32), precision: f32) void {
//     const unrounded_layout = tree.getUnroundedLayout(node_id);
//     var layout = unrounded_layout.*;

//     const current_cumulative = cumulative.add(unrounded_layout.location);

//     layout.location.x = round(unrounded_layout.location.x, precision);
//     layout.location.y = round(unrounded_layout.location.y, precision);
//     layout.size.x = round(current_cumulative.x + unrounded_layout.size.x, precision) - round(current_cumulative.x, precision);
//     layout.size.y = round(current_cumulative.y + unrounded_layout.size.y, precision) - round(current_cumulative.y, precision);
//     layout.scrollbar_size.x = round(unrounded_layout.scrollbar_size.x, precision);
//     layout.scrollbar_size.y = round(unrounded_layout.scrollbar_size.y, precision);
//     layout.border.left = round(current_cumulative.x + unrounded_layout.border.left, precision) - round(current_cumulative.x, precision);
//     layout.border.right = round(current_cumulative.x + unrounded_layout.size.x, precision) - round(current_cumulative.x + unrounded_layout.size.x - unrounded_layout.border.right, precision);
//     layout.border.top = round(current_cumulative.y + unrounded_layout.border.top, precision) - round(current_cumulative.y, precision);
//     layout.border.bottom = round(current_cumulative.y + unrounded_layout.size.y, precision) - round(current_cumulative.y + unrounded_layout.size.y - unrounded_layout.border.bottom, precision);
//     layout.padding.left = round(current_cumulative.x + unrounded_layout.padding.left, precision) - round(current_cumulative.x, precision);
//     layout.padding.right = round(current_cumulative.x + unrounded_layout.size.x, precision) - round(current_cumulative.x + unrounded_layout.size.x - unrounded_layout.padding.right, precision);
//     layout.padding.top = round(current_cumulative.y + unrounded_layout.padding.top, precision) - round(current_cumulative.y, precision);
//     layout.padding.bottom = round(current_cumulative.y + unrounded_layout.size.y, precision) - round(current_cumulative.y + unrounded_layout.size.y - unrounded_layout.padding.bottom, precision);

//     layout.content_size.x = round(current_cumulative.x + unrounded_layout.content_size.x, precision) - round(current_cumulative.x, precision);
//     layout.content_size.y = round(current_cumulative.y + unrounded_layout.content_size.y, precision) - round(current_cumulative.y, precision);

//     tree.setLayout(node_id, layout);
//     for (tree.getChildren(node_id).items) |child_id| {
//         round_inner(child_id, tree, current_cumulative, precision);
//     }
// }

fn round_inner(node_id: Node.NodeId, tree: *Tree, cumulative: Point(f32), comptime precision: f32) void {
    const unrounded_layout = tree.getUnroundedLayout(node_id);
    var layout = unrounded_layout.*;

    const current_cumulative = cumulative.add(unrounded_layout.location);

    layout.location.x = round(unrounded_layout.location.x, precision);
    layout.location.y = round(unrounded_layout.location.y, precision);
    layout.size.x = round(current_cumulative.x + unrounded_layout.size.x, precision) - round(current_cumulative.x, precision);
    layout.size.y = round(current_cumulative.y + unrounded_layout.size.y, precision) - round(current_cumulative.y, precision);
    layout.scrollbar_size.x = round(unrounded_layout.scrollbar_size.x, precision);
    layout.scrollbar_size.y = round(unrounded_layout.scrollbar_size.y, precision);
    layout.border.left = round(current_cumulative.x + unrounded_layout.border.left, precision) - round(current_cumulative.x, precision);
    layout.border.right = round(current_cumulative.x + unrounded_layout.size.x, precision) - round(current_cumulative.x + unrounded_layout.size.x - unrounded_layout.border.right, precision);
    layout.border.top = round(current_cumulative.y + unrounded_layout.border.top, precision) - round(current_cumulative.y, precision);
    layout.border.bottom = round(current_cumulative.y + unrounded_layout.size.y, precision) - round(current_cumulative.y + unrounded_layout.size.y - unrounded_layout.border.bottom, precision);
    layout.padding.left = round(current_cumulative.x + unrounded_layout.padding.left, precision) - round(current_cumulative.x, precision);
    layout.padding.right = round(current_cumulative.x + unrounded_layout.size.x, precision) - round(current_cumulative.x + unrounded_layout.size.x - unrounded_layout.padding.right, precision);
    layout.padding.top = round(current_cumulative.y + unrounded_layout.padding.top, precision) - round(current_cumulative.y, precision);
    layout.padding.bottom = round(current_cumulative.y + unrounded_layout.size.y, precision) - round(current_cumulative.y + unrounded_layout.size.y - unrounded_layout.padding.bottom, precision);

    layout.content_size.x = round(current_cumulative.x + unrounded_layout.content_size.x, precision) - round(current_cumulative.x, precision);
    layout.content_size.y = round(current_cumulative.y + unrounded_layout.content_size.y, precision) - round(current_cumulative.y, precision);

    // layout.location.x = round(unrounded_layout.location.x, precision);
    // layout.location.y = round(unrounded_layout.location.y, precision);
    // layout.size.x = round(unrounded_layout.size.x, precision);
    // layout.size.y = round(unrounded_layout.size.y, precision);
    // layout.scrollbar_size.x = round(unrounded_layout.scrollbar_size.x, precision);
    // layout.scrollbar_size.y = round(unrounded_layout.scrollbar_size.y, precision);
    // layout.border.left = round(unrounded_layout.border.left, precision);
    // layout.border.right = round(unrounded_layout.border.right, precision);
    // layout.border.top = round(unrounded_layout.border.top, precision);
    // layout.border.bottom = round(unrounded_layout.border.bottom, precision);
    // layout.padding.left = round(unrounded_layout.padding.left, precision);
    // layout.padding.right = round(unrounded_layout.padding.right, precision);
    // layout.padding.top = round(unrounded_layout.padding.top, precision);
    // layout.padding.bottom = round(unrounded_layout.padding.bottom, precision);
    // layout.content_size.x = round(unrounded_layout.content_size.x, precision);
    // layout.content_size.y = round(unrounded_layout.content_size.y, precision);

    tree.setLayout(node_id, layout);

    for (tree.getChildren(node_id).items) |child_id| {
        round_inner(child_id, tree, current_cumulative, precision);
    }
}

pub fn round_layout(node_id: Node.NodeId, tree: *Tree, comptime precision: f32) void {
    round_inner(node_id, tree, .{ .x = 0.0, .y = 0.0 }, precision);
}
