const std = @import("std");
const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;
const LayoutTree = mod.LayoutTree;
const LayoutNode = mod.LayoutNode;
const ContainerContext = mod.ContainerContext;

pub fn computeInlineContextLayout(context: *LayoutContext, container: ContainerContext, l_node_id: LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult {
    _ = container; // autofix
    context.info(l_node_id, "computeInlineContextLayout", .{});
    const l_node = context.layout_tree.getNodePtr(l_node_id);
    _ = l_node; // autofix

    // TODO
    return .{
        .size = .{ .x = 5, .y = 10 },
    };
}
