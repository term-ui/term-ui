const std = @import("std");
const Tree = @import("../tree/Tree.zig");
const Node = @import("../tree/Node.zig");
const Style = @import("../tree/Style.zig");
const styles = @import("styles.zig");
const NodeId = Node.NodeId;

const StyleSpecificity = struct {
    id: u32 = 0, // ID selectors
    classes: u32 = 0, // Class selectors
    types: u32 = 0, // Type selectors
    elements: u32 = 0, // Element (tag) selectors

    pub fn isHigherThan(self: StyleSpecificity, other: StyleSpecificity) bool {
        if (self.id != other.id) return self.id > other.id;
        if (self.classes != other.classes) return self.classes > other.classes;
        if (self.types != other.types) return self.types > other.types;
        return self.elements > other.elements;
    }
};

/// Represents a single style rule
pub const StyleRule = struct {
    style: Style, // Style properties to apply
    specificity: StyleSpecificity, // Rule's specificity

    pub fn init(allocator: std.mem.Allocator) StyleRule {
        return .{
            .style = Style.init(allocator),
            .specificity = .{},
        };
    }

    pub fn deinit(self: *StyleRule) void {
        _ = self; // autofix
    }
};

/// Main style manager that handles style application and cascade logic
pub const StyleManager = struct {
    allocator: std.mem.Allocator,
    styles_by_tag: std.StringHashMap(StyleRule),
    styles_by_class: std.StringHashMap(StyleRule),

    pub fn init(allocator: std.mem.Allocator) !StyleManager {
        return StyleManager{
            .allocator = allocator,
            .styles_by_tag = std.StringHashMap(StyleRule).init(allocator),
            .styles_by_class = std.StringHashMap(StyleRule).init(allocator),
        };
    }

    pub fn deinit(self: *StyleManager) void {
        var tag_iter = self.styles_by_tag.iterator();
        while (tag_iter.next()) |entry| {
            var rule_ptr = entry.value_ptr;
            rule_ptr.deinit();
        }
        self.styles_by_tag.deinit();

        var class_iter = self.styles_by_class.iterator();
        while (class_iter.next()) |entry| {
            var rule_ptr = entry.value_ptr;
            rule_ptr.deinit();
        }
        self.styles_by_class.deinit();
    }

    /// Computes the cascaded style for a node
    pub fn computeCascadedStyle(self: *StyleManager, tree: *Tree, node_id: NodeId) Style {
        var computed_style = Style.init(self.allocator);
        const node = tree.getNode(node_id);

        // Copy direct node style properties
        computed_style.copyFrom(&node.styles);

        // Apply inherited properties from parent
        if (node.parent) |parent_id| {
            self.applyInheritedProperties(tree, parent_id, &computed_style);
        }

        return computed_style;
    }

    // Apply inherited properties from parent to child style
    fn applyInheritedProperties(self: *StyleManager, tree: *Tree, parent_id: NodeId, style: *Style) void {
        _ = self; // Not used yet
        const parent_style = tree.getStyle(parent_id);

        // Apply foreground color if set to inherit or not set
        if (style.foreground_color == null) {
            style.foreground_color = parent_style.foreground_color;
        }

        // Apply text-align if set to inherit
        if (style.text_align == .inherit) {
            style.text_align = parent_style.text_align;
        }

        // Apply text-wrap if set to inherit
        if (style.text_wrap == .inherit) {
            style.text_wrap = parent_style.text_wrap;
        }

        // Other properties can be added here as needed
    }
};

// Structure to hold computed styles for each node
pub const ComputedStyleCache = struct {
    allocator: std.mem.Allocator,
    styles: std.AutoHashMap(NodeId, Style),

    pub fn init(allocator: std.mem.Allocator) !ComputedStyleCache {
        return ComputedStyleCache{
            .allocator = allocator,
            .styles = std.AutoHashMap(NodeId, Style).init(allocator),
        };
    }

    pub fn deinit(self: *ComputedStyleCache) void {
        var iter = self.styles.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.styles.deinit();
    }

    pub fn getOrCompute(self: *ComputedStyleCache, manager: *StyleManager, tree: *Tree, node_id: NodeId) !*Style {
        // Return cached style if available
        if (self.styles.getPtr(node_id)) |style| {
            return style;
        }

        // Compute new style and cache it
        const computed_style = manager.computeCascadedStyle(tree, node_id);
        try self.styles.put(node_id, computed_style);
        return self.styles.getPtr(node_id).?;
    }

    pub fn invalidate(self: *ComputedStyleCache, node_id: NodeId) void {
        if (self.styles.getPtr(node_id)) |style_ptr| {
            style_ptr.deinit();
            _ = self.styles.remove(node_id);
        }
    }

    pub fn invalidateTree(self: *ComputedStyleCache, tree: *Tree, node_id: NodeId) void {
        // Invalidate this node
        self.invalidate(node_id);

        // Invalidate all children recursively
        for (tree.getChildren(node_id).items) |child_id| {
            self.invalidateTree(tree, child_id);
        }
    }
};
