# CSSOM Cascading Style System

This system implements a CSS-like cascading style sheet model for the TUI library. It provides a way to define styles that cascade down the node tree, with proper inheritance and specificity.

## Core Components

1. **ComputedStyleCache**: Manages the computed style for each node, handling style inheritance and caching
2. **StyleManager**: Handles style rules and computing cascaded styles
3. **CascadeTypes**: Defines how different style properties inherit and cascade
4. **Selector**: Provides a CSS-like selector system for targeting nodes (groundwork for future expansion)
5. **StyleSheet**: Manages collections of style rules

## How Cascading Works

The cascading style system follows these principles:

1. Styles are stored directly on nodes
2. When rendering, the system computes the final "computed style" by:
   - Starting with the node's own style
   - Inheriting properties from parent nodes according to inheritance rules
   - Applying specificity rules for conflicting properties

## Inheritance Rules

Style properties follow different inheritance behaviors:

- **Always inherit**: Properties like foreground color that inherit by default
- **Explicit inherit**: Properties like text-align that only inherit when explicitly set to "inherit"
- **Never inherit**: Layout properties like display, position, etc. that never inherit

## Future Expansion

The system is designed to be extended with:

1. More complex CSS-like selectors
2. Class and ID-based selection
3. Priority based on selector specificity
4. External stylesheet parsing
5. Media queries and conditional styles

## Example Usage

Using the computed style system:

```zig
// Create style cache
var style_cache = try ComputedStyleCache.init(allocator);
defer style_cache.deinit();

// Get computed style for a node (calculates style including inheritance)
const computed_style = try style_cache.getComputedStyle(tree, node_id);

// Use computed properties
if (computed_style.foreground_color) |color| {
    // Use the color...
}

// Invalidate cache when styles change
style_cache.invalidateTree(tree, node_id);
```