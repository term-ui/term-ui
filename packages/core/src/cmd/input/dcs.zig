const std = @import("std");
const fmt = @import("../../fmt.zig");

pub const Dcs = struct {
    pub const ParameterSelector = enum(u8) {
        // User-Defined Keys (DECUDK)
        // P s = 0 → Clear all UDK definitions before starting (default)
        // P s = 1 → Erase Below (default)
        user_defined_keys = 0,

        // Request Status String (DECRQSS)
        request_status_string = 1,

        // Request Termcap/Terminfo String (xterm, experimental)
        request_termcap_terminfo = 2,

        _,
    };

    // Specific DECRQSS request types
    pub const StatusStringType = enum {
        decsca, // " q
        decscl, // " p
        decstbm, // r
        sgr, // m
        unknown,
    };

    parameter_selector: ParameterSelector,
    parameter_text: []const u8,

    // For DECUDK, these fields store additional parameters
    clear_definitions: bool = true, // P s = 0 → Clear all UDK definitions (default)
    lock_keys: bool = true, // P s = 0 → Lock the keys (default)

    // For DECRQSS, this stores the specific status request type
    status_request_type: StatusStringType = .unknown,

    pub fn parse(sequence: []const u8) ?Dcs {
        const start_bytes: usize = switch (sequence[0]) {
            '\x1b' => switch (sequence[1]) {
                'P' => 2,
                else => return null,
            },
            0x90 => 1,
            else => return null,
        };

        // Control strings (like OSC and DCS) can be terminated in three different ways:
        // BEL (0x07) - A single bell character
        // ST (0x9C) - A single "String Terminator" character
        // ESC \ (0x1B 0x5C) - A two-byte sequence with ESC followed by backslash
        const end_bytes_len: usize = switch (sequence[sequence.len - 1]) {
            '\\' => switch (sequence[sequence.len - 2]) {
                0x1b => 2,
                else => return null,
            },
            0x07, 0x9c => 1,
            else => return null,
        };

        // Extract the body (between intro and terminator)
        const body_bytes = sequence[start_bytes .. sequence.len - end_bytes_len];

        // Parse based on the first character to determine the type of DCS
        if (body_bytes.len == 0) {
            return null;
        }

        if (body_bytes[0] == '$' and body_bytes.len > 2 and body_bytes[1] == 'q') {
            // Request Status String (DECRQSS): DCS $ q Pt ST
            var status_type: StatusStringType = .unknown;

            if (body_bytes.len > 3) {
                status_type = switch (body_bytes[3]) {
                    'q' => if (body_bytes[2] == '"') .decsca else .unknown,
                    'p' => if (body_bytes[2] == '"') .decscl else .unknown,
                    'r' => .decstbm,
                    'm' => .sgr,
                    else => .unknown,
                };
            }

            return .{
                .parameter_selector = .request_status_string,
                .parameter_text = body_bytes[2..],
                .status_request_type = status_type,
            };
        } else if (body_bytes[0] == '+' and body_bytes.len > 2 and body_bytes[1] == 'q') {
            // Request Termcap/Terminfo String: DCS + q Pt ST
            return .{
                .parameter_selector = .request_termcap_terminfo,
                .parameter_text = body_bytes[2..],
            };
        } else {
            // User-Defined Keys (DECUDK): DCS Ps ; Ps | Pt ST
            var clear_defs = true;
            var lock = true;
            var param_text_start: usize = 0;

            // First, check if we have a pipe as the first character
            if (body_bytes.len > 0 and body_bytes[0] == '|') {
                // The parameter text starts right after the pipe
                return .{
                    .parameter_selector = .user_defined_keys,
                    .parameter_text = body_bytes[1..],
                    .clear_definitions = clear_defs,
                    .lock_keys = lock,
                };
            }

            // Parse the first parameter
            var i: usize = 0;
            while (i < body_bytes.len) {
                if (body_bytes[i] == ';') {
                    // First parameter found
                    if (i > 0) {
                        const param1 = std.fmt.parseUnsigned(u8, body_bytes[0..i], 10) catch 0;
                        clear_defs = param1 == 0;
                    }

                    // Parse second parameter
                    var j = i + 1;
                    while (j < body_bytes.len) {
                        if (body_bytes[j] == '|') {
                            // Second parameter found
                            if (j > i + 1) {
                                const param2 = std.fmt.parseUnsigned(u8, body_bytes[i + 1 .. j], 10) catch 0;
                                lock = param2 == 0;
                            }
                            param_text_start = j + 1;
                            break;
                        }
                        j += 1;
                    }

                    if (j == body_bytes.len) {
                        // No '|' found
                        param_text_start = i + 1;
                    }

                    break;
                } else if (body_bytes[i] == '|') {
                    // Found pipe without semicolon - first parameter only
                    if (i > 0) {
                        const param1 = std.fmt.parseUnsigned(u8, body_bytes[0..i], 10) catch 0;
                        clear_defs = param1 == 0;
                    }
                    param_text_start = i + 1;
                    break;
                }
                i += 1;
            }

            // If no separators were found, check if there are any parameters
            if (param_text_start == 0 and body_bytes.len > 0) {
                // Check if the body looks like a parameter
                if (body_bytes[0] >= '0' and body_bytes[0] <= '9') {
                    // Assume it's just a parameter with no text
                    const param1 = std.fmt.parseUnsigned(u8, body_bytes, 10) catch 0;
                    clear_defs = param1 == 0;
                    param_text_start = body_bytes.len; // Empty text
                } else {
                    // Assume the entire body is the parameter text
                    param_text_start = 0;
                }
            }

            return .{
                .parameter_selector = .user_defined_keys,
                .parameter_text = body_bytes[param_text_start..],
                .clear_definitions = clear_defs,
                .lock_keys = lock,
            };
        }
    }
};

test "dcs parse" {
    // Test DECUDK sequence (default parameters)
    const dcs1 = "\x1bP|ABC\x1b\\";
    const result1 = Dcs.parse(dcs1);
    try std.testing.expect(result1 != null);
    try std.testing.expectEqual(result1.?.parameter_selector, .user_defined_keys);
    try std.testing.expectEqualSlices(u8, result1.?.parameter_text, "ABC");
    try std.testing.expect(result1.?.clear_definitions == true); // Default
    try std.testing.expect(result1.?.lock_keys == true); // Default

    // Test DECUDK with parameters
    const dcs2 = "\x1bP1;1|F6/24;F7/25\x1b\\";
    const result2 = Dcs.parse(dcs2);
    try std.testing.expect(result2 != null);
    try std.testing.expectEqual(result2.?.parameter_selector, .user_defined_keys);
    try std.testing.expectEqualSlices(u8, result2.?.parameter_text, "F6/24;F7/25");
    try std.testing.expect(result2.?.clear_definitions == false); // 1 = don't clear
    try std.testing.expect(result2.?.lock_keys == false); // 1 = don't lock

    // Test DECRQSS
    const dcs3 = "\x1bP$q\"p\x1b\\"; // Request DECSCL status
    const result3 = Dcs.parse(dcs3);
    try std.testing.expect(result3 != null);
    try std.testing.expectEqual(result3.?.parameter_selector, .request_status_string);
    try std.testing.expectEqualSlices(u8, result3.?.parameter_text, "\"p");
    try std.testing.expectEqual(result3.?.status_request_type, .decscl);

    // Test Request Termcap/Terminfo
    const dcs4 = "\x1bP+q6b7470;6b7074\x1b\\"; // Requesting "kbs" and "kcbt" in hex
    const result4 = Dcs.parse(dcs4);
    try std.testing.expect(result4 != null);
    try std.testing.expectEqual(result4.?.parameter_selector, .request_termcap_terminfo);
    try std.testing.expectEqualSlices(u8, result4.?.parameter_text, "6b7470;6b7074");
}
