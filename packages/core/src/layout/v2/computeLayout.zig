const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;

pub fn computeLayout(context: *LayoutContext, available_space: mod.PointOf(mod.AvailableSpace), l_root_id: mod.LayoutNode.Id) mod.ComputeLayoutError!void {
    const root_layout = try mod.performLayout(
        context,
        .{
            .available_space = available_space,
            .known_dimensions = mod.CSSMaybePoint.NULL,
            .parent_size = .{
                .x = switch (available_space.x) {
                    .definite => available_space.x.definite,
                    else => null,
                },
                .y = switch (available_space.y) {
                    .definite => available_space.y.definite,
                    else => null,
                },
            },
            .sizing_mode = .inherent_size,
            .axis = .both,
            .vertical_margins_are_collapsible = .{ .start = false, .end = false },
            .compute_mode = .layout,
            .run_mode = .perform_layout,
        },
        l_root_id,
    );
    context.setBox(l_root_id, .{
        .size = root_layout.size,
    });
}
