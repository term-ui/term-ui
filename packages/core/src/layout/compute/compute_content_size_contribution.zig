const Point = @import("../point.zig").Point;
const styles = @import("../../styles/styles.zig");
/// Determine how much width/height a given node contributes to it's parent's content size
pub fn compute_content_size_contribution(
    location: Point(f32),
    size: Point(f32),
    content_size: Point(f32),
    overflow: Point(styles.overflow.Overflow),
) Point(f32) {
    const size_content_size_contribution: Point(f32) = .{
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
