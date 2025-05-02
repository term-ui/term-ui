pub const std_options: std.Options = .{
    .fmt_max_depth = 20,
};
const std = @import("std");
const Canvas = @import("renderer/Canvas.zig");
const Color = @import("colors/Color.zig");
const styles = @import("styles/styles.zig");

pub fn main() !void {
    // Setup terminal output
    const stdout = std.io.getStdOut();
    const writer = stdout.writer().any();

    // Create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create arena for gradient parsing
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // Create canvas
    var canvas = try Canvas.init(
        allocator,
        .{ .x = 100, .y = 50 }, // Taller canvas for more examples
        Color.tw.black,
        Color.tw.white,
    );
    defer canvas.deinit();

    // Clear terminal and setup display
    try writer.writeAll("\x1B[2J\x1B[H\x1B[?25l"); // Clear screen, move cursor home, hide cursor
    try writer.print("\n=== Linear Gradient Direction Debug Demo ===\n\n", .{});

    // Ensure we show the cursor again when done or on error
    defer writer.writeAll("\x1B[?25h") catch {}; // Show cursor

    // Set anti-aliasing for crisp display
    canvas.setAntiAliasingSamples(4);

    // Create animation loop to show gradients at cardinal directions
    var timer = try std.time.Timer.start();
    var last_frame_time = timer.read();
    var last_fps_update = last_frame_time;
    const frame_time_target_ns = std.time.ns_per_s / 30; // 30 FPS target
    var counter: u32 = 0;
    var active_mode: u32 = 0;
    var fps: f32 = 0.0;
    var frames_since_update: u32 = 0;

    // Demo will run for 60 seconds
    const run_duration_ns: u64 = 60 * std.time.ns_per_s;
    const start_time = timer.read();
    var elapsed_ns: u64 = 0;

    while (elapsed_ns < run_duration_ns) {
        elapsed_ns = timer.read() - start_time;

        // Limit frame rate
        const frame_delta = timer.read() - last_frame_time;
        if (frame_delta < frame_time_target_ns) {
            const sleep_ns = frame_time_target_ns - frame_delta;
            std.time.sleep(sleep_ns);
            continue;
        }

        // Calculate FPS
        frames_since_update += 1;
        const fps_time = timer.read();
        const time_since_fps_update = fps_time - last_fps_update;
        if (time_since_fps_update > std.time.ns_per_s) {
            fps = @as(f32, @floatFromInt(frames_since_update)) * std.time.ns_per_s / @as(f32, @floatFromInt(time_since_fps_update));
            frames_since_update = 0;
            last_fps_update = fps_time;
        }

        last_frame_time = timer.read();

        // Auto switch between modes every 5 seconds
        if (counter % 150 == 0) { // At 30fps, 150 frames is about 5 seconds
            active_mode = (active_mode + 1) % 3;
        }
        counter += 1;

        try canvas.clear();

        // Display title
        try canvas.drawString(.{ .x = 25, .y = 1 }, "Linear Gradient Direction Debug", Color.tw.cyan_500);

        // Switch between different demos
        switch (active_mode) {
            0 => try drawFixedDirectionsDemo(&canvas, arena.allocator()),
            1 => try drawRotatingDemo(&canvas, arena.allocator(), counter),
            2 => try drawComparisonDemo(&canvas, arena.allocator()),
            else => {},
        }

        // Display mode info and status
        const mode_text = switch (active_mode) {
            0 => "Fixed Cardinal Directions (N, NE, E, SE, S, SW, W, NW)",
            1 => "Continuous Rotation (use this to find specific issues)",
            2 => "Direction Comparison (CSS and actual render)",
            else => "Unknown mode",
        };
        try canvas.drawString(.{ .x = 2, .y = 46 }, try std.fmt.allocPrint(arena.allocator(), "FPS: {d:.2}", .{fps}), Color.tw.red_500);
        try canvas.drawString(.{ .x = 2, .y = 47 }, try std.fmt.allocPrint(arena.allocator(), "Mode {d}/3: {s}", .{ active_mode + 1, mode_text }), Color.tw.yellow_500);
        try canvas.drawString(.{ .x = 2, .y = 48 }, "Auto-switching modes every 5 seconds. Press Ctrl+C to exit.", Color.tw.gray_500);

        // Render the frame
        try writer.writeAll("\x1B[H");
        try canvas.render(writer);
    }

    // Clear screen one more time before exiting
    try writer.writeAll("\x1B[2J\x1B[H");
    try writer.print("\nGradient direction debug demo complete.\n", .{});
}

// Draw a demo showing fixed cardinal directions
fn drawFixedDirectionsDemo(canvas: *Canvas, allocator: std.mem.Allocator) !void {
    // Title
    try canvas.drawString(.{ .x = 2, .y = 3 }, "Cardinal Direction Gradients:", Color.tw.green_500);

    // Create a gradient for each of the 8 cardinal directions
    // In CSS, 0deg points to the top (bottom to top), and angle increases clockwise
    const directions = [_]struct { angle: u32, name: []const u8, desc: []const u8 }{
        .{ .angle = 0, .name = "0°", .desc = "to top" }, // Bottom to top
        .{ .angle = 45, .name = "45°", .desc = "to top right" }, // Bottom-left to top-right
        .{ .angle = 90, .name = "90°", .desc = "to right" }, // Left to right
        .{ .angle = 135, .name = "135°", .desc = "to bottom right" }, // Top-left to bottom-right
        .{ .angle = 180, .name = "180°", .desc = "to bottom" }, // Top to bottom
        .{ .angle = 225, .name = "225°", .desc = "to bottom left" }, // Top-right to bottom-left
        .{ .angle = 270, .name = "270°", .desc = "to left" }, // Right to left
        .{ .angle = 315, .name = "315°", .desc = "to top left" }, // Bottom-right to top-left
    };

    // Layout parameters
    const box_size: u32 = 16;
    const start_y: u32 = 5;
    var row: u32 = 0;
    var col: u32 = 0;

    for (directions, 0..) |dir, i| {
        col = @as(u32, @intCast(i % 4));
        row = @as(u32, @intCast(i / 4));

        const pos_x = 2 + col * (box_size + 10);
        const pos_y = start_y + row * (box_size + 8);

        var buf: [128]u8 = undefined;
        // CSS uses the "to [direction]" syntax or the angle in degrees
        // We'll use the angle format for consistency
        const gradient_str = try std.fmt.bufPrint(&buf, "linear-gradient({d}deg, red, blue)", .{dir.angle});
        const gradient = styles.background.parse(allocator, gradient_str, 0) catch unreachable;

        try canvas.drawString(.{ .x = pos_x, .y = pos_y }, try std.fmt.allocPrint(allocator, "{d}° ({s})", .{ gradient.value.linear_gradient.angle, dir.desc }), Color.tw.blue_400);

        canvas.drawRectBg(.{ .pos = .{ .x = pos_x, .y = pos_y + 1 }, .size = .{ .x = box_size, .y = box_size } }, gradient.value);
    }
}

// Draw a demo with continuously rotating gradient
fn drawRotatingDemo(canvas: *Canvas, allocator: std.mem.Allocator, angle: u32) !void {
    const width = canvas.size.x;
    const height = canvas.size.y;

    // Create a linear gradient that rotates based on the angle
    const angle_deg = angle % 360;

    // In CSS:
    // - 0deg = gradient runs from bottom to top (up)
    // - 90deg = gradient runs from left to right
    // - 180deg = gradient runs from top to bottom (down)
    // - 270deg = gradient runs from right to left

    // Create our linear gradient string using the CSS angle convention
    const linear_gradient_str = try std.fmt.allocPrint(allocator, "linear-gradient({d}deg, red, blue)", .{angle_deg});
    defer allocator.free(linear_gradient_str);

    const gradient = styles.background.parse(allocator, linear_gradient_str, 0) catch unreachable;

    // Center point of the canvas for drawing the indicator
    const center_x = width / 2;
    const center_y = height / 2;
    const radius = @min(center_x, center_y) - 2; // 2 pixels from the edge

    // Draw a box in the center showing the gradient
    const box_size: u32 = 30;
    const box_x = center_x - box_size / 2;
    const box_y = center_y - 5;
    canvas.drawRectBg(.{ .pos = .{ .x = box_x, .y = box_y }, .size = .{ .x = box_size, .y = box_size } }, gradient.value);

    // The CSS angle starts at 0 = up (bottom to top) and goes clockwise
    // For our indicator, we need to adjust the angle to match this system
    const indicator_angle_rad = @as(f32, @floatFromInt(angle_deg)) * std.math.pi / 180.0;

    // Calculate position on the circle based on current angle
    // Clamp values within the range that can be safely converted to u32
    const cos_val = @cos(indicator_angle_rad) * @as(f32, @floatFromInt(radius));
    const sin_val = -@sin(indicator_angle_rad) * @as(f32, @floatFromInt(radius)); // Negative since y increases downward in terminal

    // Safely convert to integers by clamping to u32 range
    const cos_clamped = std.math.clamp(cos_val, -@as(f32, @floatFromInt(center_x)), @as(f32, @floatFromInt(center_x)));
    const sin_clamped = std.math.clamp(sin_val, -@as(f32, @floatFromInt(center_y)), @as(f32, @floatFromInt(center_y)));

    const indicator_x_i32 = @as(i32, @intFromFloat(cos_clamped)) + @as(i32, @intCast(center_x));
    const indicator_y_i32 = @as(i32, @intFromFloat(sin_clamped)) + @as(i32, @intCast(center_y));

    // Draw the gradient info
    try canvas.drawString(.{ .x = center_x / 2, .y = 5 }, "Rotating Gradient:", Color.tw.green_500);
    try canvas.drawString(.{ .x = center_x / 2, .y = 7 }, try std.fmt.allocPrint(allocator, "Current angle: {d}°", .{angle_deg}), Color.tw.blue_400);

    // Draw a line from the center to the edge of the circle
    try canvas.drawString(.{ .x = center_x, .y = center_y - 15 }, "Direction Indicator:", Color.tw.blue_400);

    // Convert i32 back to u32 safely for drawing
    const safe_x = if (indicator_x_i32 >= 0) @as(u32, @intCast(indicator_x_i32)) else 0;
    const safe_y = if (indicator_y_i32 >= 0) @as(u32, @intCast(indicator_y_i32)) else 0;

    // Draw the angle as text at the indicator position
    if (safe_x < width and safe_y < height) {
        try canvas.drawString(.{ .x = safe_x, .y = safe_y }, try std.fmt.allocPrint(allocator, "{d}°", .{angle_deg}), Color.tw.yellow_500);
    }

    // Use a while loop to draw the line from center to edge (the direction the gradient travels)
    var r: u32 = 0;
    while (r < radius) : (r += 1) {
        const line_val_x = @cos(indicator_angle_rad) * @as(f32, @floatFromInt(r));
        const line_val_y = -@sin(indicator_angle_rad) * @as(f32, @floatFromInt(r)); // Negative for y-axis

        const line_x_i32 = @as(i32, @intCast(center_x)) + @as(i32, @intFromFloat(line_val_x));
        const line_y_i32 = @as(i32, @intCast(center_y)) + @as(i32, @intFromFloat(line_val_y));

        // Ensure x and y are within valid range before drawing
        if (line_x_i32 >= 0 and line_x_i32 < @as(i32, @intCast(width)) and
            line_y_i32 >= 0 and line_y_i32 < @as(i32, @intCast(height)))
        {
            const line_x = @as(u32, @intCast(line_x_i32));
            const line_y = @as(u32, @intCast(line_y_i32));
            canvas.drawRectBg(.{ .pos = .{ .x = line_x, .y = line_y }, .size = .{ .x = 1, .y = 1 } }, Color.tw.green_500);
        }
    }

    // Additional helper info about what CSS angle means
    try canvas.drawString(.{ .x = 2, .y = 11 }, try std.fmt.allocPrint(allocator, "CSS {d}deg: Gradient runs from bottom toward {d}°", .{ angle_deg, angle_deg }), Color.tw.gray_500);
}

// Draw a demo comparing CSS angles and rendered angles
fn drawComparisonDemo(canvas: *Canvas, allocator: std.mem.Allocator) !void {
    try canvas.drawString(.{ .x = 2, .y = 3 }, "CSS Direction vs. Angle Comparison:", Color.tw.green_500);

    const directions = [_]struct { name: []const u8, css: []const u8, angle: u32 }{
        .{ .name = "to top", .css = "to top", .angle = 0 },
        .{ .name = "to right", .css = "to right", .angle = 90 },
        .{ .name = "to bottom", .css = "to bottom", .angle = 180 },
        .{ .name = "to left", .css = "to left", .angle = 270 },
        .{ .name = "to top right", .css = "to top right", .angle = 45 },
        .{ .name = "to bottom right", .css = "to bottom right", .angle = 135 },
        .{ .name = "to bottom left", .css = "to bottom left", .angle = 225 },
        .{ .name = "to top left", .css = "to top left", .angle = 315 },
    };

    var y: u32 = 5;
    for (directions) |dir| {
        var buf1: [128]u8 = undefined;
        var buf2: [128]u8 = undefined;
        const css_str = try std.fmt.bufPrint(&buf1, "linear-gradient({s}, red, blue)", .{dir.css});
        const angle_str = try std.fmt.bufPrint(&buf2, "linear-gradient({d}deg, red, blue)", .{dir.angle});

        const css_gradient = styles.background.parse(allocator, css_str, 0) catch unreachable;
        const angle_gradient = styles.background.parse(allocator, angle_str, 0) catch unreachable;

        try canvas.drawString(.{ .x = 2, .y = y }, try std.fmt.allocPrint(allocator, "'{s}' vs '{d}deg':", .{ dir.name, dir.angle }), Color.tw.blue_400);

        // CSS direction gradient
        try canvas.drawString(.{ .x = 30, .y = y }, "CSS:", Color.tw.gray_500);
        canvas.drawRectBg(.{ .pos = .{ .x = 40, .y = y }, .size = .{ .x = 20, .y = 4 } }, css_gradient.value);

        // Angle gradient
        try canvas.drawString(.{ .x = 65, .y = y }, "Angle:", Color.tw.gray_500);
        canvas.drawRectBg(.{ .pos = .{ .x = 75, .y = y }, .size = .{ .x = 20, .y = 4 } }, angle_gradient.value);

        y += 5;
    }
}
