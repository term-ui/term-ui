const std = @import("std");
const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;
const LayoutTree = mod.LayoutTree;
const LayoutNode = mod.LayoutNode;
const ContainerContext = mod.ContainerContext;

const CSSPoint = mod.CSSPoint;
const CSSMaybePoint = mod.CSSMaybePoint;
const css_types = @import("../../css/types.zig");

pub fn computeBlockLayout(context: *LayoutContext, inputs: ContainerContext, l_node_id: LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult {
    context.info(l_node_id, "computeBlockLayout", .{});
    const l_node = context.layout_tree.getNodePtr(l_node_id);
    _ = l_node; // autofix
    const available_space = inputs.available_space;
    const parent_size = inputs.parent_size;

    const maybe_container_size = CSSMaybePoint{
        .x = switch (available_space.x) {
            .definite => available_space.x.definite,
            else => null,
        },
        .y = switch (available_space.y) {
            .definite => available_space.y.definite,
            else => null,
        },
    };
    _ = maybe_container_size; // autofix
    // Get style values
    const css_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, l_node_id, .size);
    const css_min_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, l_node_id, .min_size);
    const css_max_size = context.getStyleValue(css_types.LengthPercentageAutoPoint, l_node_id, .max_size);
    const css_margins = context.getStyleValue(css_types.LengthPercentageAutoRect, l_node_id, .margin);
    const css_padding = context.getStyleValue(css_types.LengthPercentageRect, l_node_id, .padding);
    const css_border = context.getStyleValue(css_types.LengthPercentageRect, l_node_id, .border_width);
    const css_inset = context.getStyleValue(css_types.LengthPercentageAutoRect, l_node_id, .inset);
    _ = css_inset; // autofix
    const css_position = context.getStyleValue(css_types.Position, l_node_id, .position);
    _ = css_position; // autofix
    const css_display = context.getStyleValue(css_types.Display, l_node_id, .display);
    const css_overflow = context.getStyleValue(css_types.OverflowPoint, l_node_id, .overflow);
    _ = css_overflow; // autofix
    const css_aspect_ratio = context.getStyleValue(?f32, l_node_id, .aspect_ratio);

    // Resolve margins
    const margin = mod.CSSRect{
        .top = mod.math.maybeResolve(css_margins.top, parent_size.x) orelse 0,
        .right = mod.math.maybeResolve(css_margins.right, parent_size.x) orelse 0,
        .bottom = mod.math.maybeResolve(css_margins.bottom, parent_size.x) orelse 0,
        .left = mod.math.maybeResolve(css_margins.left, parent_size.x) orelse 0,
    };
    const padding = mod.CSSRect{
        .top = mod.math.maybeResolve(css_padding.top, parent_size.x) orelse 0,
        .right = mod.math.maybeResolve(css_padding.right, parent_size.x) orelse 0,
        .bottom = mod.math.maybeResolve(css_padding.bottom, parent_size.x) orelse 0,
        .left = mod.math.maybeResolve(css_padding.left, parent_size.x) orelse 0,
    };
    const border = mod.CSSRect{
        .top = mod.math.maybeResolve(css_border.top, parent_size.x) orelse 0,
        .right = mod.math.maybeResolve(css_border.right, parent_size.x) orelse 0,
        .bottom = mod.math.maybeResolve(css_border.bottom, parent_size.x) orelse 0,
        .left = mod.math.maybeResolve(css_border.left, parent_size.x) orelse 0,
    };
    const maybe_min_size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
        .x = mod.math.maybeResolve(css_min_size.x, parent_size.x),
        .y = mod.math.maybeResolve(css_min_size.y, parent_size.y),
    }, css_aspect_ratio);

    const maybe_max_size = mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
        .x = mod.math.maybeResolve(css_max_size.x, parent_size.x),
        .y = mod.math.maybeResolve(css_max_size.y, parent_size.y),
    }, css_aspect_ratio);

    const clamped_style_size = switch (inputs.sizing_mode) {
        .inherent_size => mod.math.maybeApplyAspectRatio(mod.CSSMaybePoint{
            .x = mod.math.maybeResolve(css_size.x, parent_size.x),
            .y = mod.math.maybeResolve(css_size.y, parent_size.y),
        }, css_aspect_ratio),
        else => mod.CSSMaybePoint.NULL,
    };
    const padding_border_size = mod.CSSPoint{
        .x = padding.sumHorizontal() + border.sumHorizontal(),
        .y = padding.sumVertical() + border.sumVertical(),
    };

    // If both min and max in a given axis are set and max <= min then this determines the size in that axis
    var min_max_definite_size = mod.CSSMaybePoint.NULL;
    if (maybe_min_size.x) |min| if (maybe_max_size.x) |max| if (max <= min) {
        min_max_definite_size.x = min;
    };

    if (maybe_min_size.y) |min| if (maybe_max_size.y) |max| if (max <= min) {
        min_max_definite_size.y = min;
    };

    // Block nodes automatically stretch fit their width to fit available space if available space is definite
    const available_space_based_size = mod.CSSMaybePoint{
        .x = if (css_display.outside != .@"inline") mod.math.maybeSub(switch (available_space.x) {
            .definite => available_space.x.definite,
            else => null,
        }, margin.sumHorizontal()) else null,
        .y = null,
    };

    const styled_based_known_dimensions = mod.CSSMaybePoint{
        .x = mod.math.maybeMax(inputs.known_dimensions.x orelse min_max_definite_size.x orelse clamped_style_size.x orelse available_space_based_size.x, padding_border_size.x),
        .y = mod.math.maybeMax(inputs.known_dimensions.y orelse min_max_definite_size.y orelse clamped_style_size.y orelse available_space_based_size.y, padding_border_size.y),
    };
    if (inputs.run_mode == .compute_size and styled_based_known_dimensions.x != null and styled_based_known_dimensions.y != null) {
        return .{
            .size = .{
                .x = styled_based_known_dimensions.x.?,
                .y = styled_based_known_dimensions.y.?,
            },
        };
    }

    return try computeInner(context, .{
        .known_dimensions = styled_based_known_dimensions,

        // unchanged
        .run_mode = inputs.run_mode,
        .sizing_mode = inputs.sizing_mode,
        .axis = inputs.axis,
        .parent_size = inputs.parent_size,
        .available_space = inputs.available_space,
        .vertical_margins_are_collapsible = inputs.vertical_margins_are_collapsible,
        .compute_mode = inputs.compute_mode,
    }, l_node_id);
}

const BlockItem = struct {
    node_id: LayoutNode.Id,
    /// The "source order" of the item. This is the index of the item within the children iterator,
    /// and controls the order in which the nodes are placed
    order: u32,
    /// The base size of this item
    size: mod.CSSMaybePoint,
    /// The minimum allowable size of this item
    min_size: mod.CSSMaybePoint,
    /// The maximum allowable size of this item
    max_size: mod.CSSMaybePoint,
    /// The overflow style of the item
    overflow: css_types.OverflowPoint,
    /// The width of the item's scrollbars (if it has scrollbars)
    scrollbar_width: f32,
    /// The position style of the item
    position: css_types.Position,
    /// The final offset of this item
    inset: css_types.LengthPercentageAutoRect,
    /// The margin of this item
    margin: css_types.LengthPercentageAutoRect,
    /// The margin of this item
    padding: mod.CSSRect,
    /// The margin of this item
    border: mod.CSSRect,
    /// The sum of padding and border for this item
    padding_border_sum: mod.CSSPoint,
    /// The computed border box size of this item
    computed_size: mod.CSSPoint,
    /// The computed "static position" of this item. The static position is the position
    /// taking into account padding, border, margins, and scrollbar_gutters but not inset
    static_position: mod.CSSPoint,
    /// Whether margins can be collapsed through this item
    can_be_collapsed_through: bool,
};

/// Computes the layout of [`LayoutPartialTree`] according to the block layout algorithm
fn computeInner(allocator: std.mem.Allocator, node_id: Node.NodeId, tree: *Tree, inputs: ContainerContext) mod.ComputeLayoutError!mod.LayoutResult {
    //should be "pub fn computeInner(context: *LayoutContext, inputs: ContainerContext, l_node_id: LayoutNode.Id) mod.ComputeLayoutError!mod.LayoutResult"
    const style = tree.getComputedStyle(node_id);
    const raw_padding = style.padding;
    const raw_border = style.border;
    const raw_margin = style.margin;
    const aspect_ratio = style.aspect_ratio;
    const size = style.size.maybeResolve(inputs.parent_size).maybeApplyAspectRatio(aspect_ratio);
    const min_size = style.min_size.maybeResolve(inputs.parent_size).maybeApplyAspectRatio(aspect_ratio);
    const max_size = style.max_size.maybeResolve(inputs.parent_size).maybeApplyAspectRatio(aspect_ratio);

    const padding = style.padding.maybeResolve(inputs.parent_size.x).orZero();
    const border = style.border.maybeResolve(inputs.parent_size.x).orZero();

    // Scrollbar gutters are reserved when the `overflow` property is set to `Overflow::Scroll`.
    // However, the axis are switched (transposed) because a node that scrolls vertically needs
    // *horizontal* space to be reserved for a scrollbar
    const scrollbar_width = style.scrollbar_width;
    const overflow = style.overflow;
    const scrollbar_gutter: Rect(f32) = .{
        // TODO: make side configurable based on the `direction` property
        .top = 0,
        .left = 0,
        .right = if (overflow.y == .scroll) scrollbar_width else 0,
        .bottom = if (overflow.x == .scroll) scrollbar_width else 0,
    };

    const padding_border = padding.add(border);
    const padding_border_size = padding_border.sumAxes();
    const content_box_inset = padding_border.add(scrollbar_gutter);
    const container_content_box_size = inputs.known_dimensions.maybeSub(content_box_inset.sumAxes());

    // Determine margin collapsing behaviour
    const own_margins_collapse_with_children = Line(bool){
        .start = inputs.vertical_margins_are_collapsible.start //
        and !overflow.x.isScrollContainer() //
        and !overflow.y.isScrollContainer() //
        and style.position == .relative //
        and padding.top == 0 //
        and border.top == 0,
        .end = inputs.vertical_margins_are_collapsible.end //
        and !overflow.x.isScrollContainer() //
        and !overflow.y.isScrollContainer() //
        and style.position == .relative //
        and padding.bottom == 0 //
        and border.bottom == 0 //
        and size.y == null, //
    };

    const display = style.display;
    const has_styles_preventing_being_collapsed_through = display.outside != .block //
    or overflow.x.isScrollContainer() //
    or overflow.y.isScrollContainer() //
    or style.position == .absolute //
    or padding.top > 0 //
    or padding.bottom > 0 //
    or border.top > 0 or border.bottom > 0;

    // 1. Generate items
    var items = try generateItemList(allocator, node_id, tree, container_content_box_size);

    // 2. Compute container width
    const container_outer_width: f32 = inputs.known_dimensions.x orelse blk: {
        const available_width = inputs.available_space.x.maybeSubtractIfDefinite(content_box_inset.sumHorizontal());
        const intrinsic_width = (try determineContentBasedContainerWidth(allocator, node_id, tree, &items, available_width)) + content_box_inset.sumHorizontal();
        break :blk Maybe.max(Maybe.clamp(intrinsic_width, min_size.x, max_size.x), padding_border_size.x);
    };
    // Short-circuit if computing size and both dimensions known
    if (inputs.run_mode == .compute_size) if (inputs.known_dimensions.y) |container_outer_height| {
        return LayoutOutput{
            .size = mod.CSSPoint{
                .x = container_outer_width,
                .y = container_outer_height,
            },
        };
    };

    // 3. Perform final item layout and return content height
    const resolved_padding = raw_padding.maybeResolve(container_outer_width);
    const resolved_border = raw_border.maybeResolve(container_outer_width);
    const resolved_content_box_inset = resolved_padding.add(resolved_border).add(scrollbar_gutter);
    const inflow_content_size, const intrinsic_outer_height, const first_child_top_margin_set, const last_child_bottom_margin_set = try performFinalLayoutOnInFlowChildren(
        allocator,
        tree,
        node_id,
        &items,
        container_outer_width,
        content_box_inset,
        resolved_content_box_inset,
        own_margins_collapse_with_children,
    );

    const container_outer_height = inputs.known_dimensions.y orelse blk: {
        const clampped = Maybe.clamp(intrinsic_outer_height, min_size.y, max_size.y);
        break :blk Maybe.max(clampped, padding_border_size.y);
    };

    const final_outer_size = mod.CSSPoint{
        .x = container_outer_width,
        .y = container_outer_height,
    };

    if (inputs.run_mode == .compute_size) {
        return LayoutOutput{
            .size = final_outer_size,
        };
    }

    // 4. Layout absolutely positioned children
    const absolute_position_inset = resolved_border.add(scrollbar_gutter);
    const absolute_position_area = final_outer_size.sub(absolute_position_inset.sumAxes());
    const absolute_position_offset = mod.CSSPoint{
        .x = absolute_position_inset.left,
        .y = absolute_position_inset.top,
    };
    const absolute_content_size = try performAbsoluteLayoutOnAbsoluteChildren(allocator, items, absolute_position_area, absolute_position_offset, tree);

    // 5. Perform hidden layout on hidden children
    for (tree.getChildren(node_id).items, 0..) |child_id, order| {
        const child_style = tree.getComputedStyle(child_id);
        if (child_style.display.outside == .none) {
            tree.setUnroundedLayout(child_id, Layout{
                .order = @intCast(order),
                .margin = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
            });
            _ = try performChildLayout(
                allocator,
                child_id,
                tree,
                mod.CSSMaybePoint.NULL,
                mod.CSSMaybePoint.NULL,
                AvailableSpace.MAX_CONTENT,
                .inherent_size,
                .{ .start = false, .end = false },
            );
        }
    }
    // 7. Determine whether this node can be collapsed through
    var all_in_flow_children_can_be_collapsed_through = true;
    for (items.items) |item| {
        all_in_flow_children_can_be_collapsed_through = item.position == .absolute or item.can_be_collapsed_through;
        if (!all_in_flow_children_can_be_collapsed_through) {
            break;
        }
    }
    const can_be_collapsed_through = !has_styles_preventing_being_collapsed_through and all_in_flow_children_can_be_collapsed_through;
    const content_size = inflow_content_size.max(absolute_content_size);

    return LayoutOutput{
        .size = final_outer_size,
        .content_size = content_size,
        .first_baselines = mod.CSSMaybePoint.NULL,
        .top_margin = if (own_margins_collapse_with_children.start)
            first_child_top_margin_set
        else
            CollapsibleMarginSet.fromMargin(raw_margin.top.maybeResolve(inputs.parent_size.x) orelse 0),

        .bottom_margin = if (own_margins_collapse_with_children.end)
            last_child_bottom_margin_set
        else
            CollapsibleMarginSet.fromMargin(raw_margin.bottom.maybeResolve(inputs.parent_size.x) orelse 0),

        .margins_can_collapse_through = can_be_collapsed_through,
    };
}

pub fn generateItemList(allocator: std.mem.Allocator, node_id: Node.NodeId, tree: *Tree, nodeInnerSize: mod.CSSMaybePoint) !Array(BlockItem) {
    var order: usize = 0;
    var items = Array(BlockItem).init(allocator);
    const children = tree.getChildren(node_id).items;
    var i: usize = 0;
    while (i < children.len) : (i += 1) {
        const child_id = children[i];

        const style = tree.getComputedStyle(child_id);
        const aspect_ratio = style.aspect_ratio;

        const padding = style.padding.maybeResolve(nodeInnerSize.x).orZero();
        const border = style.border.maybeResolve(nodeInnerSize.x).orZero();

        try items.append(.{
            .node_id = child_id,
            .order = @intCast(order),
            .size = style.size.maybeResolve(nodeInnerSize).maybeApplyAspectRatio(aspect_ratio),
            .min_size = style.min_size.maybeResolve(nodeInnerSize).maybeApplyAspectRatio(aspect_ratio),
            .max_size = style.max_size.maybeResolve(nodeInnerSize).maybeApplyAspectRatio(aspect_ratio),
            .overflow = style.overflow,
            .scrollbar_width = style.scrollbar_width,
            .position = style.position,
            .inset = style.inset,
            .margin = style.margin,
            .padding = padding,
            .border = border,
            .padding_border_sum = padding.add(border).sumAxes(),

            // Fields to be computed later (for now we initialise with dummy values)
            .computed_size = .{ .x = 0, .y = 0 },
            .static_position = .{ .x = 0, .y = 0 },
            .can_be_collapsed_through = false,
        });
        order += 1;
    }
    return items;
}

pub fn determineContentBasedContainerWidth(
    allocator: std.mem.Allocator,
    node_id: Node.NodeId,
    tree: *Tree,
    items: *Array(BlockItem),
    available_width: AvailableSpace,
) !f32 {
    _ = node_id; // autofix
    var max_child_width: f32 = 0;
    const available_space = Point(AvailableSpace){
        .x = available_width,
        .y = .min_content,
    };
    const available_space_width = available_width.intoOption();
    for (items.items) |*item| {
        if (item.position == .absolute) {
            continue;
        }
        const known_dimensions: mod.CSSMaybePoint = item.size.maybeClamp(item.min_size, item.max_size);

        var width = known_dimensions.x orelse blk: {
            const item_x_margin_sum: f32 = item.margin.maybeResolve(available_space_width).orZero().sumHorizontal();
            // switch (item.nodes) {
            //     .block => |child| {
            const size_and_baselines = try performChildLayout(
                allocator,
                item.node_id,
                tree,
                known_dimensions,
                .{ .x = null, .y = null },
                .{
                    .x = available_space.x.maybeSubtractIfDefinite(item_x_margin_sum),
                    .y = .min_content,
                },
                .inherent_size,
                .{ .start = true, .end = true },
            );
            break :blk size_and_baselines.size.x + item_x_margin_sum;
            //     },
            //     .inline_stream => |nodes| {
            //         // @panic("not implemented");
            //         const size_and_baselines = try performInlineLayout(
            //             allocator,
            //             tree,
            //             node_id,
            //             nodes,
            //             known_dimensions,
            //             .{ .x = null, .y = null },
            //             .{
            //                 .x = available_space.x.maybeSubtractIfDefinite(item_x_margin_sum),
            //                 .y = .min_content,
            //             },
            //             .inherent_size,
            //             .{ .start = true, .end = true },
            //         );
            //         break :blk size_and_baselines.size.x + item_x_margin_sum;
            //     },
            // }
        };
        width = @max(width, item.padding_border_sum.x);
        max_child_width = @max(max_child_width, width);
    }
    return max_child_width;
}

fn performFinalLayoutOnInFlowChildren(
    allocator: std.mem.Allocator,
    tree: *Tree,
    root_id: Node.NodeId,
    items: *Array(BlockItem),
    container_outer_width: f32,
    content_box_inset: Rect(f32),
    resolved_content_box_inset: Rect(f32),
    own_margins_collapse_with_children: Line(bool),
) !struct { mod.CSSPoint, f32, CollapsibleMarginSet, CollapsibleMarginSet } {
    _ = root_id; // autofix

    // Resolve container_inner_width for sizing child nodes using initial content_box_inset
    //     let container_inner_width = container_outer_width - content_box_inset.horizontal_axis_sum();
    //     let parent_size = Size { width: Some(container_outer_width), height: None };
    //     let available_space =
    //         Size { width: AvailableSpace::Definite(container_inner_width), height: AvailableSpace::MinContent };
    const container_inner_width: f32 = container_outer_width - content_box_inset.sumHorizontal();
    const parent_size = mod.CSSMaybePoint{
        .x = container_outer_width,
        .y = null,
    };
    const available_space = Point(AvailableSpace){
        .x = .{ .definite = container_inner_width },
        .y = .{ .min_content = {} },
    };
    var inflow_content_size = mod.CSSPoint{
        .x = 0,
        .y = 0,
    };
    var committed_offset = mod.CSSPoint{
        .x = resolved_content_box_inset.left,
        .y = resolved_content_box_inset.top,
    };
    var first_child_top_margin_set = CollapsibleMarginSet.ZERO;
    var active_collapsible_margin_set = CollapsibleMarginSet.ZERO;
    var is_collapsing_with_first_margin_set = true;
    for (items.items) |*item| {
        if (item.position == .absolute) {
            item.static_position = committed_offset;
            continue;
        }
        const item_margin = item.margin.maybeResolve(container_outer_width);
        const item_non_auto_margin = item_margin.orZero();
        const item_non_auto_x_margin_sum = item_non_auto_margin.sumHorizontal();
        const known_dimensions: mod.CSSMaybePoint = .{
            .x = Maybe.clamp(
                item.size.x orelse container_inner_width - item_non_auto_x_margin_sum,
                item.min_size.x,
                item.max_size.x,
            ),
            .y = Maybe.clamp(item.size.y, item.min_size.y, item.max_size.y),
        };
        const item_available_space = Point(AvailableSpace){
            .x = available_space.x.maybeSubtractIfDefinite(item_non_auto_x_margin_sum),
            .y = available_space.y,
        };

        const item_layout = try performChildLayout(
            allocator,
            item.node_id,
            tree,
            known_dimensions,
            parent_size,
            item_available_space,
            .inherent_size,
            .{ .start = true, .end = true },
        );
        // const item_layout = switch (item.nodes) {
        //     .block => |child| try performChildLayout(
        //         allocator,
        //         child,
        //         tree,
        //         known_dimensions,
        //         parent_size,
        //         item_available_space,
        //         .inherent_size,
        //         .{ .start = true, .end = true },
        //     ),
        //     .inline_stream => |nodes| try performInlineLayout(
        //         allocator,
        //         tree,
        //         root_id,
        //         nodes,
        //         known_dimensions,
        //         parent_size,
        //         item_available_space,
        //         .inherent_size,
        //         .{ .start = true, .end = true },
        //     ),
        // };

        const final_size = item_layout.size;
        const top_margin_set = item_layout.top_margin.collapseWithMargin(item_margin.top orelse 0);
        const bottom_margin_set = item_layout.bottom_margin.collapseWithMargin(item_margin.bottom orelse 0);

        // Expand auto margins to fill available space
        // Note: Vertical auto-margins for relatively positioned block items simply resolve to 0.
        // See: https://www.w3.org/TR/CSS21/visudet.html#abs-non-replaced-width
        const free_x_space = @max(0, container_inner_width - final_size.x - item_non_auto_x_margin_sum);
        const x_axis_auto_margin_size = blk: {
            const auto_margin_count: f32 = @floatFromInt(@as(u8, @intFromBool(item_margin.left == null)) + @as(u8, @intFromBool(item_margin.right == null)));
            if (auto_margin_count > 0) {
                break :blk free_x_space / auto_margin_count;
            } else {
                break :blk 0;
            }
        };

        const resolved_margin: Rect(f32) = .{
            .left = item_margin.left orelse x_axis_auto_margin_size,
            .right = item_margin.right orelse x_axis_auto_margin_size,
            .top = top_margin_set.resolve(),
            .bottom = bottom_margin_set.resolve(),
        };

        // Resolve item inset
        const inset: Rect(?f32) = .{
            .top = item.inset.top.maybeResolve(0.0),
            .bottom = item.inset.bottom.maybeResolve(0.0),
            .left = item.inset.top.maybeResolve(container_inner_width),
            .right = item.inset.right.maybeResolve(container_inner_width),
        };

        const inset_offset = mod.CSSPoint{
            .x = inset.left orelse -(inset.right orelse 0),
            .y = inset.top orelse -(inset.bottom orelse 0),
        };

        const y_margin_offset = if (is_collapsing_with_first_margin_set and own_margins_collapse_with_children.start)
            0
        else
            active_collapsible_margin_set.collapseWithMargin(resolved_margin.top).resolve();

        item.computed_size = item_layout.size;
        item.can_be_collapsed_through = item_layout.margins_can_collapse_through;
        item.static_position = mod.CSSPoint{
            .x = resolved_content_box_inset.left,
            .y = committed_offset.y + active_collapsible_margin_set.resolve(),
        };

        const location = mod.CSSPoint{
            .x = resolved_content_box_inset.left + inset_offset.x + resolved_margin.left,
            .y = committed_offset.y + inset_offset.y + y_margin_offset,
        };

        const scrollbar_size = mod.CSSPoint{
            .x = if (item.overflow.y == .scroll) item.scrollbar_width else 0,
            .y = if (item.overflow.x == .scroll) item.scrollbar_width else 0,
        };
        // const inner_width = item_layout.size.x - item.padding_border_sum.x - item.border.sumHorizontal(); // - item.scrollbar_width;
        const inner_height = item_layout.size.y - item.padding_border_sum.y - item.border.sumVertical(); //- item.scrollbar_width;
        _ = inner_height; // autofix
        const content_size: mod.CSSPoint = .{
            .x = container_inner_width,
            .y = item_layout.content_size.y,
        };

        const layout: Layout = .{
            .order = item.order,
            .size = item_layout.size,
            .scrollbar_size = scrollbar_size,
            .location = location,
            .padding = item.padding,
            .border = item.border,
            .content_size = content_size,
            .margin = resolved_margin,
        };

        tree.setUnroundedLayout(item.node_id, layout);

        inflow_content_size = inflow_content_size.max(computeContentSizeContribution(
            location,
            final_size,
            item_layout.content_size,
            item.overflow,
        ));

        // Update first_child_top_margin_set
        if (is_collapsing_with_first_margin_set) {
            if (item.can_be_collapsed_through) {
                first_child_top_margin_set = first_child_top_margin_set
                    .collapseWithSet(top_margin_set)
                    .collapseWithSet(bottom_margin_set);
            } else {
                first_child_top_margin_set = first_child_top_margin_set.collapseWithSet(top_margin_set);
                is_collapsing_with_first_margin_set = false;
            }
        }

        // Update active_collapsible_margin_set
        if (item.can_be_collapsed_through) {
            active_collapsible_margin_set = active_collapsible_margin_set
                .collapseWithSet(top_margin_set)
                .collapseWithSet(bottom_margin_set);
        } else {
            committed_offset.y += item_layout.size.y + y_margin_offset;
            active_collapsible_margin_set = bottom_margin_set;
        }
    }

    const last_child_bottom_margin_set = active_collapsible_margin_set;
    const bottom_y_margin_offset = if (own_margins_collapse_with_children.end) 0 else last_child_bottom_margin_set.resolve();

    committed_offset.y += resolved_content_box_inset.bottom + bottom_y_margin_offset;

    const content_height = @max(0, committed_offset.y);
    return .{ inflow_content_size, content_height, first_child_top_margin_set, last_child_bottom_margin_set };
}

pub fn performAbsoluteLayoutOnAbsoluteChildren(
    allocator: std.mem.Allocator,
    items: Array(BlockItem),
    area_size: mod.CSSPoint,
    area_offset: mod.CSSPoint,
    tree: *Tree,
) !mod.CSSPoint {
    const area_width = area_size.x;
    const area_height = area_size.y;
    var absolute_content_size = mod.CSSPoint{
        .x = 0,
        .y = 0,
    };

    for (items.items) |*item| {
        const child_id = item.node_id;
        const child_style = tree.getComputedStyle(child_id);
        const display = child_style.display;
        if (display.outside == .none or child_style.position != .absolute) {
            continue;
        }

        const aspect_ratio = child_style.aspect_ratio;
        const margin = child_style.margin.maybeResolve(area_width);
        const padding = child_style.padding.maybeResolve(area_width);
        const border = child_style.border.maybeResolve(area_width);
        const padding_border_sum = padding.add(border).sumAxes();

        // Resolve inset
        const left = child_style.inset.left.maybeResolve(area_width);
        const right = child_style.inset.right.maybeResolve(area_width);
        const top = child_style.inset.top.maybeResolve(area_height);
        const bottom = child_style.inset.bottom.maybeResolve(area_height);

        // Compute known dimensions from min/max/inherent size styles
        const style_size = child_style.size.maybeResolve(area_size).maybeApplyAspectRatio(aspect_ratio);
        const min_size = child_style
            .min_size
            .maybeResolve(area_size)
            .maybeApplyAspectRatio(aspect_ratio)
            .orElse(padding_border_sum)
            .maybeMax(padding_border_sum);
        const max_size = child_style.max_size.maybeResolve(area_size).maybeApplyAspectRatio(aspect_ratio);
        var known_dimensions = style_size.maybeClamp(min_size, max_size);

        // Fill in width from left/right and reapply aspect ratio if:
        //  - Width is not already known
        //  - Item has both left and right inset properties set
        if (known_dimensions.x == null) if (left) |_left| if (right) |_right| {
            const new_width_raw = Maybe.sub(Maybe.sub(area_width, margin.left), margin.right) - _left - _right;
            known_dimensions.x = @max(new_width_raw, 0);
            known_dimensions = known_dimensions.maybeApplyAspectRatio(aspect_ratio).maybeClamp(min_size, max_size);
        };

        // Fill in height from top/bottom and reapply aspect ratio if:
        // - Height is not already known
        // - Item has both top and bottom inset properties set
        if (known_dimensions.y == null) if (top) |_top| if (bottom) |_bottom| {
            const new_height_raw = Maybe.sub(Maybe.sub(area_height, margin.top), margin.bottom) - _top - _bottom;
            known_dimensions.y = @max(new_height_raw, 0);
            known_dimensions = known_dimensions.maybeApplyAspectRatio(aspect_ratio).maybeClamp(min_size, max_size);
        };

        const layout_output = try performChildLayout(
            allocator,
            child_id,
            tree,
            known_dimensions,
            area_size.intoOptional(),
            .{
                .x = .{ .definite = Maybe.clamp(area_width, min_size.x, max_size.x) },
                .y = .{ .definite = Maybe.clamp(area_height, min_size.y, max_size.y) },
            },
            .content_size,
            .{ .start = false, .end = false },
        );
        const measured_size = layout_output.size;

        const final_size = known_dimensions.orElse(measured_size).maybeClamp(min_size, max_size);

        const non_auto_margin = Rect(f32){
            .left = if (left) |_| margin.left orelse 0 else 0,
            .right = if (right) |_| margin.right orelse 0 else 0,
            .top = if (top) |_| margin.top orelse 0 else 0,
            .bottom = if (bottom) |_| margin.left orelse 0 else 0,
        };

        // Expand auto margins to fill available space
        // https://www.w3.org/TR/CSS21/visudet.html#abs-non-replaced-width

        const auto_margin: Rect(f32) = blk: {
            // Auto margins for absolutely positioned elements in block containers only resolve
            // if inset is set. Otherwise they resolve to 0.
            const absolute_auto_margin_space = mod.CSSPoint{
                .x = if (right) |r| area_size.x - r - (left orelse 0) else final_size.x,
                .y = if (bottom) |b| area_size.y - b - (top orelse 0) else final_size.y,
            };

            const free_space: mod.CSSPoint = .{
                .x = absolute_auto_margin_space.x - final_size.x - non_auto_margin.sumHorizontal(),
                .y = absolute_auto_margin_space.y - final_size.y - non_auto_margin.sumVertical(),
            };
            const auto_margin_size: mod.CSSPoint = .{

                // If all three of 'left', 'width', and 'right' are 'auto': First set any 'auto' values for 'margin-left' and 'margin-right' to 0.
                // Then, if the 'direction' property of the element establishing the static-position containing block is 'ltr' set 'left' to the
                // static position and apply rule number three below; otherwise, set 'right' to the static position and apply rule number one below.
                //
                // If none of the three is 'auto': If both 'margin-left' and 'margin-right' are 'auto', solve the equation under the extra constraint
                // that the two margins get equal values, unless this would make them negative, in which case when direction of the containing block is
                // 'ltr' ('rtl'), set 'margin-left' ('margin-right') to zero and solve for 'margin-right' ('margin-left'). If one of 'margin-left' or
                // 'margin-right' is 'auto', solve the equation for that value. If the values are over-constrained, ignore the value for 'left' (in case
                // the 'direction' property of the containing block is 'rtl') or 'right' (in case 'direction' is 'ltr') and solve for that value.
                .x = width: {
                    const auto_margin_count: f32 = @floatFromInt(@as(u8, @intFromBool(left == null)) + @as(u8, @intFromBool(right == null)));

                    if (auto_margin_count == 2 //
                    and (style_size.x == null or style_size.x.? >= free_space.x)) {
                        break :width 0;
                    } else if (auto_margin_count > 0) {
                        break :width free_space.x / auto_margin_count;
                    } else {
                        break :width 0;
                    }
                },

                .y = height: {
                    const auto_margin_count: f32 = @floatFromInt(@as(u8, @intFromBool(top == null)) + @as(u8, @intFromBool(bottom == null)));

                    if (auto_margin_count == 2 //
                    and (style_size.y == null or style_size.y.? >= free_space.y)) {
                        break :height 0;
                    } else if (auto_margin_count > 0) {
                        break :height free_space.y / auto_margin_count;
                    } else {
                        break :height 0;
                    }
                },
            };

            break :blk Rect(f32){
                .left = if (margin.left) |_| 0 else auto_margin_size.x,
                .right = if (margin.right) |_| 0 else auto_margin_size.x,
                .top = if (margin.top) |_| 0 else auto_margin_size.y,
                .bottom = if (margin.bottom) |_| 0 else auto_margin_size.y,
            };
        };

        const resolved_margin = Rect(f32){
            .left = margin.left orelse auto_margin.left,
            .right = margin.right orelse auto_margin.right,
            .top = margin.top orelse auto_margin.top,
            .bottom = margin.bottom orelse auto_margin.bottom,
        };

        const location = mod.CSSPoint{
            .x = width: {
                var width = if (left) |_left| _left + resolved_margin.right else null;
                width = if (right) |_right| area_size.x - final_size.x - _right - resolved_margin.left else width;
                break :width Maybe.add(width, area_offset.x) orelse item.static_position.y + resolved_margin.left;
            },
            .y = height: {
                var height = if (top) |_top| _top + resolved_margin.bottom else null;
                height = if (bottom) |_bottom| area_size.y - final_size.y - _bottom - resolved_margin.top else height;
                break :height Maybe.add(height, area_offset.y) orelse item.static_position.y + resolved_margin.top;
            },
        };

        const scrollbar_size = mod.CSSPoint{
            .x = if (item.overflow.y == .scroll) item.scrollbar_width else 0,
            .y = if (item.overflow.x == .scroll) item.scrollbar_width else 0,
        };

        tree.setUnroundedLayout(child_id, Layout{
            .order = item.order,
            .size = final_size,
            .content_size = layout_output.content_size,
            .scrollbar_size = scrollbar_size,
            .location = location,
            .padding = padding,
            .border = border,
            .margin = resolved_margin,
        });

        absolute_content_size = absolute_content_size.max(computeContentSizeContribution(
            location,
            final_size,
            layout_output.content_size,
            item.overflow,
        ));
    }

    return absolute_content_size;
}

test "computeBlockLayout" {
    const allocator = std.testing.allocator;
    const doc_xml =
        \\<div>
        \\  <p>Hello, world!</p>
        \\  <p>Hello, world!</p>
        \\</div>
        \\
    ;
    var tree = try mod.docFromXml(allocator, doc_xml, .{});
    defer tree.deinit();

    var lt = try mod.LayoutTree.fromTree(allocator, &tree);
    defer lt.deinit();
    var context = LayoutContext{
        .layout_tree = &lt,
        .doc_tree = &tree,
        .allocator = allocator,
    };
    try mod.computeLayout(
        &context,
        .{ .x = .{ .definite = 100 }, .y = .max_content },
        0,
    );
    try context.layout_tree.printRoot(std.io.getStdErr().writer().any());
}
