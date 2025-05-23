const std = @import("std");
const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;
const LayoutTree = mod.LayoutTree;
const LayoutNode = mod.LayoutNode;
const ContainerContext = mod.ContainerContext;

pub fn performLayout(context: *LayoutContext, container: ContainerContext, l_node_id: LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult {
    context.info(l_node_id, "performLayout", .{});
    const l_node = context.layout_tree.getNodePtr(l_node_id);
    return switch (l_node.data) {
        .block_container_node => mod.computeBlockLayout(context, container, l_node_id),
        .inline_container_node => mod.computeInlineContextLayout(context, container, l_node_id),
        else => @panic("unimplemented"),
    };
}
