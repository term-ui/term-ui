const mod = @import("mod.zig");
const LayoutContext = mod.LayoutContext;
const LayoutNode = mod.LayoutNode;

available_space: AvailableSpacePoint,
compute_mode: ComputeMode,

/// Whether we only need to know the Node's size, or whe
run_mode: RunMode,
/// Whether a Node's style sizes should be taken into account or ignored
sizing_mode: SizingMode,
/// Which axis we need the size of
axis: RequestedAxis,

/// Known dimensions represent dimensions (width/height) which should be taken as fixed when performing layout.
/// For example, if known_dimensions.width is set to Some(WIDTH) then this means something like:
///
///    "What would the height of this node be, assuming the width is WIDTH"
///
/// Layout functions will be called with both known_dimensions set for final layout. Where the meaning is:
///
///   "The exact size of this node is WIDTHxHEIGHT. Please lay out your children"
///
known_dimensions: mod.CSSMaybePoint,
/// Parent size dimensions are intended to be used for percentage resolution.
parent_size: mod.CSSMaybePoint,
/// Available space represents an amount of space to layout into, and is used as a soft constraint
/// Specific to CSS Block layout. Used for correctly computing margin collapsing. You probably want to set this to `Line::FALSE`.
vertical_margins_are_collapsible: mod.LineOf(bool),

pub const ComputeMode = enum {
    size,
    layout,
};

pub const AvailableSpace = union(enum) {
    definite: f32,
    min_content,
    max_content,
};

pub const AvailableSpacePoint = mod.PointOf(AvailableSpace);
pub const RunMode = enum {
    /// A full layout for this node and all children should be computed
    perform_layout,
    /// The layout algorithm should be executed such that an accurate container size for the node can be determined.
    /// Layout steps that aren't necessary for determining the container size of the current node can be skipped.
    compute_size,
};

pub const SizingMode = enum {
    /// Only content contributions should be taken into account
    content_size,
    /// Inherent size styles should be taken into account in addition to content contributions
    inherent_size,
};

pub const RequestedAxis = enum {
    /// The horizontal axis
    horizontal,
    /// The vertical axis
    vertical,
    /// Both axes
    both,
};
