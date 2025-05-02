const std = @import("std");
const Canvas = @import("renderer/Canvas.zig");
const Color = @import("colors/Color.zig");
const styles = @import("styles/styles.zig");
const fmt = std.fmt;
const ChildProcess = std.process.Child;

pub fn main() !void {
    // Setup terminal output
    const stdout = std.io.getStdOut();
    const writer = stdout.writer().any();

    // Create allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create arena for gradient parsing
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // Create canvas
    var canvas = try Canvas.init(
        allocator,
        .{ .x = 100, .y = 30 }, // Larger canvas size
        Color.tw.black,
        Color.tw.white,
    );
    defer canvas.deinit();

    // // Setup terminal for
    // try configureTerminal(true);
    // defer configureTerminal(false) catch {}; // Restore terminal on exit
    try canvas.render(writer);

    // // Clear terminal and setup display
    // try writer.writeAll("\x1B[2J\x1B[H\x1B[?25l"); // Clear screen, move cursor home, hide cursor
    // defer writer.writeAll("\x1B[?25h") catch {}; // Show cursor again when done

    // // Set anti-aliasing for better display
    // canvas.setAntiAliasingSamples(4);

    // // Initial gradient angle
    // var angle: u32 = 0;
    // var gradient_type: u8 = 0; // 0: linear, 1: radial

    // // Main loop for interactive control
    // var running = true;
    // try canvas.clear();

    // // // Draw UI elements
    // // try drawUI(&canvas, angle, gradient_type);

    // // // Draw the current gradient
    // // try drawGradient(&canvas, arena.allocator(), angle, gradient_type);

    // // Render to terminal
    // while (running) {

    //     // Position cursor at the bottom of the display
    //     // try writer.print("\x1B[{d};1H", .{canvas.size.y + 2});

    //     // Process input
    //     const key = try readKey();
    //     switch (key) {
    //         .left => angle = (angle + 359) % 360, // Decrease angle (wrap around)
    //         .right => angle = (angle + 1) % 360, // Increase angle
    //         .up => gradient_type = (gradient_type + 1) % 2, // Switch gradient type
    //         .down => gradient_type = if (gradient_type == 0) 1 else 0, // Switch gradient type
    //         .quit => running = false,
    //         else => {}, // Ignore other keys
    //     }
    // }
}

const Key = enum {
    up,
    down,
    left,
    right,
    quit,
    other,
};

fn readKey() !Key {
    const stdin = std.io.getStdIn().reader();

    const first_byte = stdin.readByte() catch |err| {
        if (err == error.EndOfStream) {
            return Key.quit;
        }
        return err;
    };

    // Check for escape sequence
    if (first_byte == 27) {
        // Could be an escape sequence
        const maybe_bracket = stdin.readByte() catch return Key.quit;
        if (maybe_bracket == '[') {
            const direction = stdin.readByte() catch return Key.quit;
            return switch (direction) {
                'A' => Key.up,
                'B' => Key.down,
                'C' => Key.right,
                'D' => Key.left,
                else => Key.other,
            };
        }
        // Just ESC key
        return Key.quit;
    }

    // Check for 'q' to quit
    if (first_byte == 'q' or first_byte == 'Q') {
        return Key.quit;
    }

    return Key.other;
}

fn configureTerminal(raw_mode: bool) !void {
    // On Unix-like systems, we can execute the stty command to configure the terminal
    const command = if (raw_mode)
        "stty raw -echo -icanon"
    else
        "stty cooked echo icanon";

    var process = ChildProcess.init(&.{ "sh", "-c", command }, std.heap.page_allocator);
    process.stdin_behavior = .Inherit;
    process.stdout_behavior = .Ignore;
    process.stderr_behavior = .Ignore;

    try process.spawn();
    const result = try process.wait();

    if (result != .Exited or result.Exited != 0) {
        std.debug.print("Failed to configure terminal\n", .{});
        return error.TerminalConfigFailed;
    }
}

fn drawUI(canvas: *Canvas, angle: u32, gradient_type: u8) !void {
    // Draw title and instructions
    try canvas.drawString(.{ .x = 25, .y = 1 }, "Interactive Gradient Rotation Demo", Color.tw.cyan_500);
    try canvas.drawString(.{ .x = 2, .y = 3 }, "Use LEFT/RIGHT arrows to rotate gradient", Color.tw.green_400);
    try canvas.drawString(.{ .x = 2, .y = 4 }, "Use UP/DOWN arrows to switch gradient type", Color.tw.green_400);
    try canvas.drawString(.{ .x = 2, .y = 5 }, "Press Q to quit", Color.tw.green_400);

    // Display current angle and gradient type
    try canvas.drawString(.{ .x = 2, .y = 7 }, try fmt.allocPrint(canvas.allocator, "Current angle: {d}° ({s})", .{ angle, if (gradient_type == 0) "Linear Gradient" else "Radial Gradient" }), Color.tw.yellow_500);
}

fn drawGradient(canvas: *Canvas, allocator: std.mem.Allocator, angle: u32, gradient_type: u8) !void {
    // Box dimensions for gradient display - ensure they fit within the canvas
    const box_x: u32 = 10;
    const box_y: u32 = 10;
    const box_width: u32 = 35;
    const box_height: u32 = 15;

    // Generate gradient based on type
    var gradient_str: []const u8 = undefined;
    if (gradient_type == 0) {
        // Linear gradient with current angle
        gradient_str = try fmt.allocPrint(allocator, "linear-gradient({d}deg, red, yellow, blue)", .{angle});
    } else {
        // Radial gradient with current angle as a rotation point
        // Calculate position based on angle
        const radian = @as(f32, @floatFromInt(angle)) * std.math.pi / 180.0;
        const pos_x = 50.0 + 30.0 * @cos(radian);
        const pos_y = 50.0 + 30.0 * @sin(radian);
        gradient_str = try fmt.allocPrint(allocator, "radial-gradient(circle at {d:.1}% {d:.1}%, red, yellow, blue)", .{ pos_x, pos_y });
    }

    // Parse and render the gradient
    const gradient = styles.background.parse(allocator, gradient_str, 0) catch unreachable;
    canvas.drawRectBg(.{ .pos = .{ .x = box_x, .y = box_y }, .size = .{ .x = box_width, .y = box_height } }, gradient.value);

    // Draw an indicator line for the gradient direction
    if (gradient_type == 0) {
        try drawDirectionIndicator(canvas, angle, box_x, box_y, box_width, box_height);
    }

    // Show CSS representation
    try canvas.drawString(.{ .x = 55, .y = 10 }, "CSS:", Color.tw.blue_400);
    try canvas.drawString(.{ .x = 55, .y = 11 }, try fmt.allocPrint(allocator, "{s}", .{gradient_str}), Color.tw.blue_400);
}

fn drawDirectionIndicator(canvas: *Canvas, angle: u32, box_x: u32, box_y: u32, box_width: u32, box_height: u32) !void {
    // Calculate center of the box
    const center_x = box_x + box_width / 2;
    const center_y = box_y + box_height / 2;

    // Calculate the indicator line length
    const radius = @min(box_width, box_height) / 3;

    // Convert angle to radians for calculations
    // CSS angles: 0deg is bottom-to-top, and increases clockwise
    // Adjust the angle to match CSS convention:
    // - 0deg points to top (subtract 90 degrees from standard angle)
    const adjusted_angle = @as(f32, @floatFromInt((angle + 270) % 360));
    const angle_rad = adjusted_angle * std.math.pi / 180.0;

    // Draw the line
    var r: u32 = 0;
    while (r < radius) : (r += 1) {
        // Calculate point on line from center
        const dx = @cos(angle_rad) * @as(f32, @floatFromInt(r));
        const dy = @sin(angle_rad) * @as(f32, @floatFromInt(r)); // Terminal coordinates increase downward

        const x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(center_x)) + dx));
        const y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(center_y)) + dy));

        // Draw point if within canvas bounds
        if (x >= 0 and x < @as(i32, @intCast(canvas.size.x)) and
            y >= 0 and y < @as(i32, @intCast(canvas.size.y)))
        {
            canvas.drawRectBg(.{ .pos = .{ .x = @intCast(x), .y = @intCast(y) }, .size = .{ .x = 1, .y = 1 } }, Color.tw.green_500);
        }
    }

    // Draw arrow at the end of the line
    const arrow_x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(center_x)) + @cos(angle_rad) * @as(f32, @floatFromInt(radius))));
    const arrow_y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(center_y)) + @sin(angle_rad) * @as(f32, @floatFromInt(radius))));

    if (arrow_x >= 0 and arrow_x < @as(i32, @intCast(canvas.size.x)) and
        arrow_y >= 0 and arrow_y < @as(i32, @intCast(canvas.size.y)))
    {
        try canvas.drawString(.{ .x = @intCast(arrow_x), .y = @intCast(arrow_y) }, "→", Color.tw.yellow_500);
    }

    // Add a text explanation of the CSS direction
    const direction_text = switch (angle) {
        0 => "to top (bottom→top)",
        90 => "to right (left→right)",
        180 => "to bottom (top→bottom)",
        270 => "to left (right→left)",
        45 => "to top right",
        135 => "to bottom right",
        225 => "to bottom left",
        315 => "to top left",
        else => try fmt.allocPrint(canvas.allocator, "angle: {d}°", .{angle}),
    };

    try canvas.drawString(.{ .x = 55, .y = 15 }, try fmt.allocPrint(canvas.allocator, "Direction: {s}", .{direction_text}), Color.tw.green_400);
}
