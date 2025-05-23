const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;
const css_types = @import("../../css/types.zig");

pub fn computeChildLayout(context: *LayoutContext, inputs: mod.ContainerContext, l_node_id: mod.LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult {
    const l_node = context.layout_tree.getNodePtr(l_node_id);
    return switch (l_node.data) {
        .block_container_node => {
            const display = context.getStyleValue(css_types.Display, l_node_id, .display);
            switch (display.inside) {
                .flow_root => return mod.computeBlockLayout(context, inputs, l_node_id),
                .flex => return mod.computeFlexboxLayout(context, inputs, l_node_id),
                .flow => return mod.computeBlockLayout(context, inputs, l_node_id), // fallback to block layout
            }
        },
        .inline_container_node => mod.computeInlineContextLayout(context, inputs, l_node_id),
        else => @panic("unimplemented"),
    };
}
