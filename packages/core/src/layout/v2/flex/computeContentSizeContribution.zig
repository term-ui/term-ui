const mod = @import("../mod.zig");
const css_types = @import("../../../css/types.zig");
/// Determine how much width/height a given node contributes to it's parent's content size
pub fn computeContentSizeContribution(
    location: mod.CSSPoint,
    size: mod.CSSPoint,
    content_size: mod.CSSPoint,
    overflow: css_types.OverflowPoint,
) mod.CSSPoint {
    const size_content_size_contribution: mod.CSSPoint = .{
        .x = if (overflow.x == .visible) @max(size.x, content_size.x) else size.x,
        .y = if (overflow.y == .visible) @max(size.y, content_size.y) else size.y,
    };
    if (size_content_size_contribution.x > 0.0 and size_content_size_contribution.y > 0.0) {
        return .{
            .x = location.x + size_content_size_contribution.x,
            .y = location.y + size_content_size_contribution.y,
        };
    } else {
        return .{ .x = 0.0, .y = 0.0 };
    }
}
