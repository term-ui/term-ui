const AnyInputManager = @import("input/manager.zig").AnyInputManager;
const Match = @import("input/manager.zig").Match;
const MatchResult = @import("input/manager.zig").MatchResult;
const Event = @import("input/manager.zig").Event;
const std = @import("std");
const fmt = @import("../fmt.zig");
const Osc = @import("input/osc.zig").Osc;
const Dcs = @import("input/dcs.zig").Dcs;
const keys = @import("keys.zig");
const constants = @import("input/constants.zig");
const expectEvents = @import("./test-utils.zig").expectEvents;
const logger = @import("input/manager.zig").logger;
const TermKeyType = enum(i32) {
    unicode,
    function,
    keysym,
    mouse,
    position,
    modereport,
    dcs,
    osc,
    unknown_csi = -1,
};

// Key modifiers
const TERMKEY_KEYMOD_SHIFT: i32 = 1 << 0;
const TERMKEY_KEYMOD_ALT: i32 = 1 << 1;
const TERMKEY_KEYMOD_CTRL: i32 = 1 << 2;

// Maximum number of CSI function keys
const NCSIFUNCS: usize = 40;

// For tracking control strings
var saved_string_id: usize = 0;

const KeyInfo = struct {
    type: TermKeyType,
    sym: ?keys.Key,
    modifier_set: u32,
    modifier_mask: u32,
};

fn registerCsiSs3Full(csi_ss3s: []KeyInfo, @"type": TermKeyType, sym: ?keys.Key, modifier_set: i32, modifier_mask: i32, cmd: u8) void {
    if (cmd < 0x40 or cmd >= 0x80) {
        return;
    }

    csi_ss3s[cmd - 0x40] = KeyInfo{
        .type = @"type",
        .sym = sym,
        .modifier_set = modifier_set,
        .modifier_mask = modifier_mask,
    };
}

fn registerCsiSs3(csi_ss3s: []KeyInfo, @"type": TermKeyType, sym: keys.Key, cmd: u8) void {
    registerCsiSs3Full(csi_ss3s, @"type", sym, 0, 0, cmd);
}

fn registerSs3Kpalt(ss3s: []KeyInfo, ss3_kpalts: []u8, @"type": TermKeyType, sym: keys.Key, cmd: u8, kpalt: u8) void {
    if (cmd < 0x40 or cmd >= 0x80) {
        return;
    }

    ss3s[cmd - 0x40] = KeyInfo{
        .type = @"type",
        .sym = sym,
        .modifier_set = 0,
        .modifier_mask = 0,
    };
    ss3_kpalts[cmd - 0x40] = kpalt;
}

// Function to register CSI function keys
fn registerCsiFunc(csifuncs: []KeyInfo, @"type": TermKeyType, sym: keys.Key, number: usize) void {
    if (number >= NCSIFUNCS) {
        return;
    }

    csifuncs[number] = KeyInfo{
        .type = @"type",
        .sym = sym,
        .modifier_set = 0,
        .modifier_mask = 0,
    };
}

// Handler for CSI function keys
fn handleCsiFunc(manager: *AnyInputManager, buffer: []const u8, position: usize, csifuncs: []const KeyInfo) Match {
    _ = manager; // autofix
    _ = csifuncs; // autofix
    // Find the parameter (number before the ~)
    var param: usize = 0;
    var pos = position;
    var have_param = false;

    while (pos < buffer.len) {
        const c = buffer[pos];

        if (c >= '0' and c <= '9') {
            param = param * 10 + (c - '0');
            have_param = true;
            pos += 1;
        } else if (c == '~') {
            pos += 1;
            break;
        } else {
            return .nomatch;
        }
    }

    if (!have_param or param >= NCSIFUNCS) {
        return .nomatch;
    }

    // const info = csifuncs[param];
    // if (info.type != .unicode) {
    //     // Emit the key event
    //     manager.emitNamed(info.sym, @intCast(info.modifier_set), buffer[position..pos]);
    //     return .{ .match = pos };
    // }

    return .nomatch;
}

const KeyTables = struct {
    ss3s: [64]KeyInfo,
    ss3_kpalts: [64]u8,
    csi_ss3s: [64]KeyInfo,
    csifuncs: [NCSIFUNCS]KeyInfo,
};

const key_tables = blk: {
    const ss3s: [64]KeyInfo = [_]KeyInfo{KeyInfo{
        .type = .unknown_csi,
        .sym = null,
        .modifier_set = 0,
        .modifier_mask = 0,
    }} ** 64;
    const ss3_kpalts: [64]u8 = [_]u8{0} ** 64;
    const csi_ss3s: [64]KeyInfo = [_]KeyInfo{KeyInfo{
        .type = .unknown_csi,
        .sym = null,
        .modifier_set = 0,
        .modifier_mask = 0,
    }} ** 64;
    const csifuncs: [NCSIFUNCS]KeyInfo = [_]KeyInfo{KeyInfo{
        .type = .unknown_csi,
        .sym = null,
        .modifier_set = 0,
        .modifier_mask = 0,
    }} ** NCSIFUNCS;

    // Register known keys
    // registerCsiSs3(&csi_ss3s, .keysym, .up, 'A');
    // registerCsiSs3(&csi_ss3s, .keysym, .down, 'B');
    // registerCsiSs3(&csi_ss3s, .keysym, .right, 'C');
    // registerCsiSs3(&csi_ss3s, .keysym, .left, 'D');
    // registerCsiSs3(&csi_ss3s, .keysym, .tab, 'E'); // BEGIN key
    // registerCsiSs3(&csi_ss3s, .keysym, .end, 'F');
    // registerCsiSs3(&csi_ss3s, .keysym, .home, 'H');
    // // For function keys, we'll use F1-F4 mapped to keys .key_f1 through .key_f4
    // registerCsiSs3(&csi_ss3s, .function, .f1, 'P');
    // registerCsiSs3(&csi_ss3s, .function, .f2, 'Q');
    // registerCsiSs3(&csi_ss3s, .function, .f3, 'R');
    // registerCsiSs3(&csi_ss3s, .function, .f4, 'S');

    // registerCsiSs3Full(&csi_ss3s, .keysym, .tab, TERMKEY_KEYMOD_SHIFT, TERMKEY_KEYMOD_SHIFT, 'Z');

    // // Keypad keys
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_enter, 'M', 0);
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_equal, 'X', '=');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_plus, 'k', '+');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_comma, 'l', ',');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_minus, 'm', '-');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_period, 'n', '.');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_divide, 'o', '/');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_0, 'p', '0');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_1, 'q', '1');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_2, 'r', '2');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_3, 's', '3');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_4, 't', '4');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_5, 'u', '5');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_6, 'v', '6');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_7, 'w', '7');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_8, 'x', '8');
    // registerSs3Kpalt(&ss3s, &ss3_kpalts, .keysym, .kp_9, 'y', '9');

    // CSI Function keys
    // registerCsiFunc(&csifuncs, .keysym, .key_find, 1);
    // registerCsiFunc(&csifuncs, .keysym, .key_insert, 2); // INSERT
    // registerCsiFunc(&csifuncs, .keysym, .key_delete, 3); // DELETE
    // // registerCsiFunc(&csifuncs, .keysym, .key_select, 4);
    // registerCsiFunc(&csifuncs, .keysym, .key_page_up, 5); // PAGE UP
    // registerCsiFunc(&csifuncs, .keysym, .key_page_down, 6); // PAGE DOWN
    // registerCsiFunc(&csifuncs, .keysym, .key_home, 7);
    // registerCsiFunc(&csifuncs, .keysym, .key_end, 8);

    // // Function keys F1-F20
    // registerCsiFunc(&csifuncs, .function, .key_f1, 11);
    // registerCsiFunc(&csifuncs, .function, .key_f2, 12);
    // registerCsiFunc(&csifuncs, .function, .key_f3, 13);
    // registerCsiFunc(&csifuncs, .function, .key_f4, 14);
    // registerCsiFunc(&csifuncs, .function, .key_f5, 15);
    // registerCsiFunc(&csifuncs, .function, .key_f6, 17);
    // registerCsiFunc(&csifuncs, .function, .key_f7, 18);
    // registerCsiFunc(&csifuncs, .function, .key_f8, 19);
    // registerCsiFunc(&csifuncs, .function, .key_f9, 20);
    // registerCsiFunc(&csifuncs, .function, .key_f10, 21);
    // registerCsiFunc(&csifuncs, .function, .key_f11, 23);
    // registerCsiFunc(&csifuncs, .function, .key_f12, 24);
    // registerCsiFunc(&csifuncs, .function, .key_f13, 25);
    // registerCsiFunc(&csifuncs, .function, .key_f14, 26);
    // registerCsiFunc(&csifuncs, .function, .key_f15, 28);
    // registerCsiFunc(&csifuncs, .function, .key_f16, 29);
    // registerCsiFunc(&csifuncs, .function, .key_f17, 31);
    // registerCsiFunc(&csifuncs, .function, .key_f18, 32);
    // registerCsiFunc(&csifuncs, .function, .key_f19, 33);
    // registerCsiFunc(&csifuncs, .function, .key_f20, 34);

    break :blk KeyTables{
        .ss3s = ss3s,
        .ss3_kpalts = ss3_kpalts,
        .csi_ss3s = csi_ss3s,
        .csifuncs = csifuncs,
    };
};

pub fn handleSs3(manager: *AnyInputManager, buffer: []const u8, position: usize, intro_len: usize) Match {
    logger.info("try handleSs3", .{});
    //     static TermKeyResult peekkey_ss3(TermKey *tk, TermKeyCsi *csi, size_t introlen, TermKeyKey *key,
    //                                  int force, size_t *nbytep)
    // {
    //   if (tk->buffcount < introlen + 1) {
    //     if (!force) {
    //       return TERMKEY_RES_AGAIN;
    //     }
    //     (*tk->method.emit_codepoint)(tk, 'O', key);
    //     key->modifiers |= TERMKEY_KEYMOD_ALT;
    //     *nbytep = tk->buffcount;
    //     return TERMKEY_RES_KEY;
    //   }

    if (buffer.len <= position + intro_len) {
        if (manager.modeIsNot(.force)) {
            return .{ .partial = {} };
        }
        manager.emitFromCodepoint(
            'O',
            'o',
            .press,
            Event.mod.ALT,
            buffer[position .. position + intro_len],
        );
        return .{ .match = position + intro_len };
    }
    //   unsigned char cmd = CHARAT(introlen);
    const cmd = buffer[position + intro_len];

    // SS3 {ABCDEFHPQRS}
    // .. csv-table:: Legacy functional encoding
    //    :header: "Name", "Terminfo name", "Escape code"

    //     "INSERT",    "kich1",      "CSI 2 ~"
    //     "DELETE",    "kdch1",      "CSI 3 ~"
    //     "PAGE_UP",   "kpp",        "CSI 5 ~"
    //     "PAGE_DOWN", "knp",        "CSI 6 ~"
    //     "UP",        "cuu1,kcuu1", "CSI A, SS3 A"
    //     "DOWN",      "cud1,kcud1", "CSI B, SS3 B"
    //     "RIGHT",     "cuf1,kcuf1", "CSI C, SS3 C"
    //     "LEFT",      "cub1,kcub1", "CSI D, SS3 D"
    //     "HOME",      "home,khome", "CSI H, SS3 H"
    //     "END",       "-,kend",     "CSI F, SS3 F"
    //     "F1",        "kf1",        "SS3 P"
    //     "F2",        "kf2",        "SS3 Q"
    //     "F3",        "kf3",        "SS3 R"
    //     "F4",        "kf4",        "SS3 S"
    //     "F5",        "kf5",        "CSI 15 ~"
    //     "F6",        "kf6",        "CSI 17 ~"
    //     "F7",        "kf7",        "CSI 18 ~"
    //     "F8",        "kf8",        "CSI 19 ~"
    //     "F9",        "kf9",        "CSI 20 ~"
    //     "F10",       "kf10",       "CSI 21 ~"
    //     "F11",       "kf11",       "CSI 23 ~"
    //     "F12",       "kf12",       "CSI 24 ~"
    //     "MENU",      "kf16",       "CSI 29 ~"
    const key: keys.Key = switch (cmd) {
        'A' => .up,
        'B' => .down,
        'C' => .right,
        'D' => .left,
        'E' => .tab,
        'F' => .end,
        'H' => .home,
        'P' => .f1,
        'Q' => .f2,
        'R' => .f3,
        'S' => .f4,
        'M' => .kp_enter,
        'X' => .kp_equal,
        'j' => .kp_multiply,
        'k' => .kp_add,
        // 'l' => .kp_comma,
        'm' => .kp_subtract,
        'n' => .kp_decimal,
        'o' => .kp_divide,
        'p' => .kp_0,
        'q' => .kp_1,
        'r' => .kp_2,
        's' => .kp_3,
        't' => .kp_4,
        'u' => .kp_5,
        'v' => .kp_6,
        'w' => .kp_7,
        'x' => .kp_8,
        'y' => .kp_9,
        else => return .nomatch,
    };

    manager.emitNamed(key, .press, Event.mod.SHIFT, buffer[position .. position + intro_len + 1]);
    return .{ .match = position + intro_len + 1 };

    //   key->type = csi_ss3s[cmd - 0x40].type;
    //   key->code.sym = csi_ss3s[cmd - 0x40].sym;
    //   key->modifiers = csi_ss3s[cmd - 0x40].modifier_set;
    // var key_type = key_tables.csi_ss3s[cmd - 0x40].type;
    // var key_sym = key_tables.csi_ss3s[cmd - 0x40].sym;
    // var key_modifiers = key_tables.csi_ss3s[cmd - 0x40].modifier_set;

    //   if (key->code.sym == TERMKEY_SYM_UNKNOWN) {
    //     if (tk->flags & TERMKEY_FLAG_CONVERTKP && ss3_kpalts[cmd - 0x40]) {
    //       key->type = TERMKEY_TYPE_UNICODE;
    //       key->code.codepoint = (unsigned char)ss3_kpalts[cmd - 0x40];
    //       key->modifiers = 0;

    //       key->utf8[0] = (char)key->code.codepoint;
    //       key->utf8[1] = 0;
    //     } else {
    //       key->type = ss3s[cmd - 0x40].type;
    //       key->code.sym = ss3s[cmd - 0x40].sym;
    //       key->modifiers = ss3s[cmd - 0x40].modifier_set;
    //     }
    //   }
    // if (key_sym == null) {
    //     // TODO: handle keypad alts.. I think I'll do it upstream in the input manager..Below is the source from keyterm
    //     //     if (tk->flags & TERMKEY_FLAG_CONVERTKP && ss3_kpalts[cmd - 0x40]) {
    //     //       key->type = TERMKEY_TYPE_UNICODE;
    //     //       key->code.codepoint = (unsigned char)ss3_kpalts[cmd - 0x40];
    //     //       key->modifiers = 0;

    //     //       key->utf8[0] = (char)key->code.codepoint;
    //     //       key->utf8[1] = 0;
    //     //     }
    //     key_type = key_tables.ss3s[cmd - 0x40].type;
    //     key_sym = key_tables.ss3s[cmd - 0x40].sym;
    //     key_modifiers = key_tables.ss3s[cmd - 0x40].modifier_set;
    // }

    // if (key_sym) |sym| {
    //     manager.emitNamed(sym, @intCast(key_modifiers), buffer[position .. position + intro_len + 1]);
    //     return .{ .match = position + intro_len + 1 };
    // }

    // manager.emitNamed(key_sym, @intCast(key_modifiers), buffer[position .. position + intro_len + 1]);
    // return .{ .match = position + intro_len + 1 };
    // return .nomatch;
}

// Handler for control strings (DCS, OSC)
fn handleCtrlString(manager: *AnyInputManager, buffer: []const u8, position: usize, intro_len: usize) Match {
    logger.info("try handleCtrlString", .{});
    // Find the end of the control string
    var str_end = position + intro_len;
    while (str_end < buffer.len) {
        if (buffer[str_end] == 0x07) { // BEL
            break;
        }
        if (buffer[str_end] == 0x9c) { // ST
            break;
        }
        if (buffer[str_end] == 0x1b and
            (str_end + 1) < buffer.len and
            buffer[str_end + 1] == 0x5c)
        { // ESC-prefixed ST
            break;
        }

        str_end += 1;
    }

    // If we didn't find an end marker, we need more data
    if (str_end >= buffer.len) {
        return .{ .partial = {} };
    }

    // Calculate the total length including the terminator
    var total_length = str_end - position + 1;
    if (buffer[str_end] == 0x1b) {
        total_length += 1; // Add one more for the ESC-prefixed ST
    }

    const intro_char = if (intro_len > 0) buffer[position + intro_len - 1] else 0;
    switch (intro_char) {
        'P', 0x90 => {
            const dcs = Dcs.parse(buffer[position..str_end]) orelse std.debug.panic("TODO: handle dcs failures", .{});
            manager.emitDcs(dcs, buffer[position..str_end]);
            return .{ .match = total_length };
        },
        ']', 0x92 => {
            const osc = Osc.parse(buffer[position..str_end]) orelse std.debug.panic("TODO: handle osc failures", .{});
            manager.emitOsc(osc, buffer[position..str_end]);
            return .{ .match = total_length };
        },
        else => {
            std.debug.panic("unknown ctrlstring {c}", .{intro_char});
        },
    }
    return .nomatch;
}

const RawCsi = struct {
    parameters: [16][]const u8,
    parameter_count: usize,
    cmd_byte: u8,
    initial_byte: u8,
    raw: []const u8,
    // Assumes the param is validated.. if it contains non-digits, it will parse up to the last digit
    // if empty, it will return 0
    pub fn parseSimpleInt(param: []const u8) u32 {
        if (param.len == 0) {
            return 0;
        }

        return std.fmt.parseUnsigned(u32, param, 10) catch 0;
    }
    const SuffixedInt = struct {
        int: u32 = 0,
        suffix: u8 = 0,
    };

    pub fn parseSuffixedInt(param: []const u8) SuffixedInt {
        if (param.len == 0) {
            return .{ .int = 0, .suffix = 0 };
        }
        var end: usize = 0;
        while (end < param.len and std.ascii.isDigit(param[end])) {
            end += 1;
        }
        if (end < param.len) {
            // expects a single non-digit character after the digits
            std.debug.assert(param.len - end == 1);
            return .{ .int = std.fmt.parseUnsigned(u32, param[0..end], 10) catch 0, .suffix = param[end] };
        }
        return .{ .int = std.fmt.parseUnsigned(u32, param[0..end], 10) catch 0, .suffix = 0 };
    }

    const WithSubParams = struct {
        parameters: [4]SuffixedInt = [_]SuffixedInt{.{ .int = 0, .suffix = 0 }} ** 4,
        parameter_count: usize = 0,
    };
    pub fn parseWithSubParams(params: []const u8) WithSubParams {
        var result = WithSubParams{};
        // var params_index = 0;
        var iter = std.mem.splitScalar(u8, params, ':');
        while (iter.next()) |param| {
            result.parameters[result.parameter_count] = parseSuffixedInt(param);
            result.parameter_count += 1;
        }
        return result;
    }
    pub fn parseColonSeparated(self: RawCsi, param_index: usize) struct {
        before: SuffixedInt,
        after: SuffixedInt,
    } {
        var param = self.parameters[param_index];
        var end = param.len;
        while (end > 0 and param[end - 1] != ':') {
            end -= 1;
        }

        return .{
            .before = parseSuffixedInt(param[0..end]),
            .after = parseSuffixedInt(param[end + 1 ..]),
        };
    }
    pub fn parseParamAsSimpleInt(self: RawCsi, param_index: usize) u32 {
        return parseSimpleInt(self.parameters[param_index]);
    }
    pub fn parseParamAsSuffixedInt(self: RawCsi, param_index: usize) SuffixedInt {
        return parseSuffixedInt(self.parameters[param_index]);
    }
    pub fn parseParamAsColonSeparated(self: RawCsi, param_index: usize) struct {
        before: SuffixedInt,
        after: SuffixedInt,
    } {
        return parseColonSeparated(self, param_index);
    }
    pub fn parseParamAsWithSubParams(self: RawCsi, param_index: usize) ?WithSubParams {
        if (self.parameters.len <= param_index) {
            return null;
        }
        return parseWithSubParams(self.parameters[param_index]);
    }
};
const MAX_PARAMETERS: usize = 16;
// this could mitakenly catch sequences with no ending byte (ex. x10 mouse events). So we need to handle that separately later
pub fn parseCsi(
    buffer: []const u8,
    position: usize,
    intro_len: usize,
) MatchResult(RawCsi) {
    var end = position + intro_len;
    while (end < buffer.len) {
        if (buffer[end] >= 0x40 and buffer[end] < 0x80) {
            break;
        }
        end += 1;
    }

    logger.info("[RAW CSI] {s}", .{buffer[position .. end + 1]});
    if (end >= buffer.len) {
        return .partial;
    }

    // See if there is an initial byte
    var raw_csi = RawCsi{
        .parameters = undefined,
        .parameter_count = 0,
        .cmd_byte = buffer[end],
        .initial_byte = 0,
        .raw = buffer[position .. end + 1],
    };

    var params_start = position + intro_len;
    if (params_start < end and buffer[params_start] >= '<' and buffer[params_start] <= '?') {
        raw_csi.initial_byte = buffer[params_start];
        params_start += 1;
    }

    while (params_start < end) {
        var param_end = params_start;
        while (param_end < end and buffer[param_end] != ';') {
            param_end += 1;
        }
        raw_csi.parameters[raw_csi.parameter_count] = buffer[params_start..param_end];
        raw_csi.parameter_count += 1;
        params_start = param_end + 1;
    }

    return .{ .match = raw_csi };
}
test "parseCsi" {
    {
        const result = parseCsi("\x1b[1;23;34m", 0, 2);
        try std.testing.expectEqual(result.match.parameter_count, 3);
        try std.testing.expectEqualSlices(u8, result.match.parameters[0], "1");
        try std.testing.expectEqualSlices(u8, result.match.parameters[1], "23");
        try std.testing.expectEqualSlices(u8, result.match.parameters[2], "34");
    }

    {
        const result = parseCsi("\x1b[;;34m", 0, 2);
        try std.testing.expectEqual(result.match.parameter_count, 3);
        try std.testing.expectEqualSlices(u8, result.match.parameters[0], "");
        try std.testing.expectEqualSlices(u8, result.match.parameters[1], "");
        try std.testing.expectEqualSlices(u8, result.match.parameters[2], "34");
    }

    // try std.testing.expectEqual(result.match.parameter_count, 3);
}
// pub fn interpretMouseEvent(raw_csi: RawCsi) Match {
//     _ = raw_csi; // autofix

//     // X10 compatibility mode
//     // X10 compatibility mode sends an escape sequence only on button press,
//     // encoding the location and the mouse button pressed.  It is enabled by
//     // specifying parameter 9 to DECSET.  On button press, xterm sends CSI M
//     // CbCxCy (6 characters).

//     // o   Cb is button-1, where button is 1, 2 or 3.

//     // o   Cx and Cy are the x and y coordinates of the mouse when the button
//     //     was pressed.
//     return .nomatch;
// }
// static TermKeyResult peekkey_mouse(TermKey *tk, TermKeyKey *key, size_t *nbytep)
// {
//   if (tk->buffcount < 3) {
//     return TERMKEY_RES_AGAIN;
//   }
//   key->type = TERMKEY_TYPE_MOUSE;
//   key->code.mouse[0] = (char)CHARAT(0) - 0x20;
//   key->code.mouse[1] = (char)CHARAT(1) - 0x20;
//   key->code.mouse[2] = (char)CHARAT(2) - 0x20;
//   key->code.mouse[3] = 0;

//   key->modifiers = (key->code.mouse[0] & 0x1c) >> 2;
//   key->code.mouse[0] &= ~0x1c;

//   *nbytep = 3;
//   return TERMKEY_RES_KEY;
// }

// handles x10 and normal tracking mouse events
pub fn interpretNormalTrackingMouseEvent(manager: *AnyInputManager, buffer: []const u8, position: usize, intro_len: usize) Match {
    var mouse = Event.Mouse{
        .normal = .{
            .action = .left_press,
            .x = 0,
            .y = 0,
        },
    };
    var modifiers: u8 = 0;
    const slice = buffer[position + intro_len ..];
    if (slice.len < 3) {
        return .partial;
    }
    mouse.normal.x = slice[1] - 0x20;
    mouse.normal.y = slice[2] - 0x20;
    var button: u8 = slice[0] - 0x20;
    modifiers = (button & 0x1c) >> 2;

    // Handle special buttons (wheel mice and other buttons)
    if (button & 0x40 != 0) { // Buttons 4-7 (wheel mice and tilting)
        button &= ~@as(u8, 0x40);

        if (button & 0x03 == 0) { // Button 4 (wheel forward)
            mouse.normal.action = .wheel_forward;
        } else if (button & 0x03 == 1) { // Button 5 (wheel back)
            mouse.normal.action = .wheel_back;
        } else if (button & 0x03 == 2) { // Button 6 (wheel tilt right)
            mouse.normal.action = .wheel_tilt_right;
        } else if (button & 0x03 == 3) { // Button 7 (wheel tilt left)
            mouse.normal.action = .wheel_tilt_left;
        }
    } else if (button & 0x80 != 0) { // Buttons 8-11
        // For buttons 8-11, we'll reuse the same actions as buttons 0-3
        // since the spec notes the encoding gets ambiguous after button 11
        button &= ~@as(u8, 0x80);

        mouse.normal.action = switch (button & 0x03) {
            0 => .left_press,
            1 => .middle_press,
            2 => .right_press,
            3 => .release,
            else => .left_press,
        };
    } else {
        // Normal buttons 0-3
        button &= 0x03;
        mouse.normal.action = switch (button) {
            0 => .left_press,
            1 => .middle_press,
            2 => .right_press,
            3 => .release,
            else => .left_press,
        };
    }

    const len = intro_len + 3;
    manager.emitMouse(mouse, modifiers, buffer[position .. position + len]);
    return .{ .match = len };
}

// Handles CSI $y and CSI ?$y mode status reports
pub fn interpretModeStatusReport(manager: *AnyInputManager, csi: RawCsi, raw: []const u8) Match {
    // Command byte must be 'y'
    if (csi.cmd_byte != 'y') {
        return .nomatch;
    }

    // Need at least 2 parameters
    if (csi.parameter_count < 2) {
        return .nomatch;
    }

    // Check if this is a Mode Status Report by looking for '$' either as a suffix to the second parameter
    // or as a character in the raw sequence
    var is_mode_report = false;
    var mode_byte: u8 = 0;
    var value1: u16 = 0;
    var value2: u8 = 0;

    // Check for $ in raw sequence
    for (csi.raw) |c| {
        if (c == '$') {
            is_mode_report = true;
            break;
        }
    }

    if (!is_mode_report) {
        return .nomatch;
    }

    // There are two forms:
    // 1. CSI ? <mode> ; <value> $ y - where ? is the initial byte
    // 2. CSI <mode> ; <value> $ y - no initial byte, mode is the first parameter

    if (csi.initial_byte != 0) {
        // Form 1: CSI ? <mode> ; <value> $ y
        mode_byte = csi.initial_byte;
        const param0 = csi.parseParamAsSimpleInt(0);
        const param1 = csi.parseParamAsSimpleInt(1);
        value1 = @truncate(param0);
        value2 = @truncate(param1);
    } else {
        // Form 2: CSI <mode> ; <value> $ y
        // In form 2, the mode is in parameter 0, value is in parameter 1
        const mode_value = csi.parseParamAsSimpleInt(0);
        const value = csi.parseParamAsSimpleInt(1);

        // In this form, we're not using mode_byte (which would be 0)
        // Instead, value1 contains the mode value
        value1 = @truncate(mode_value);
        value2 = @truncate(value);
    }

    manager.emitModeReport(mode_byte, value1, value2, raw);
    return .{ .match = raw.len };
}

// Handles CSI u sequences for extended Unicode keys and Kitty keyboard protocol
pub fn interpretUnicodeKey(manager: *AnyInputManager, csi: RawCsi, raw: []const u8) Match {
    // switch (csi.cmd_byte) {
    //     'u' => {},
    //     'A' => {},
    //     'B' => {},
    //     'C' => {},
    // }

    // Need at least 1 parameter (the codepoint)
    if (csi.parameter_count < 1) {
        return .nomatch;
    }
    const alternates = csi.parseParamAsWithSubParams(0) orelse return .nomatch;
    const unicode_key, const shifted_key, const base_layout_key, _ = alternates.parameters;

    const mod_and_event = csi.parseParamAsWithSubParams(1) orelse RawCsi.WithSubParams{
        .parameters = .{
            .{},
            .{},
            .{},
            .{},
        },
        .parameter_count = 3,
    };

    const parsed_modifiers, const event_type, _, _ = mod_and_event.parameters;
    const action: Event.KeyAction = switch (event_type.int) {
        0 => .press,
        1 => .press,
        2 => .repeat,
        3 => .release,
        else => std.debug.panic("TODO: handle invalid event type {}\n", .{event_type.int}),
    };
    const modifiers: u8 = @truncate(@max(parsed_modifiers.int, 1) - 1);
    logger.debug("unicode_key: {}\n", .{unicode_key.int});

    switch (csi.cmd_byte) {
        'u' => {
            const cp: u21 = @truncate(unicode_key.int);
            const text_param = csi.parseParamAsWithSubParams(2);
            const text_cp = blk: {
                if (text_param) |t| {
                    if (t.parameter_count > 0 and t.parameters[0].int > 0) {
                        break :blk t.parameters[0].int;
                    }
                }
                if (shifted_key.int > 0) {
                    break :blk shifted_key.int;
                }
                break :blk unicode_key.int;
            };
            manager.emitFromCodepoint(
                constants.getFunctionalNumberFromCsiNumber(@truncate(text_cp)),
                cp,
                action,
                modifiers,
                csi.raw,
            );
        },
        else => {
            manager.emitNamed(
                switch (csi.cmd_byte) {
                    'A' => .up,
                    'B' => .down,
                    'C' => .right,
                    'D' => .left,
                    'E' => .kp_begin,
                    'F' => .end,
                    'H' => .home,
                    'P' => .f1,
                    'Q' => .f2,
                    'S' => .f4,
                    '~' => switch (unicode_key.int) {
                        //   ["f3", 13, "~", false],
                        //   ["f5", 15, "~", false],
                        //   ["f6", 17, "~", false],
                        //   ["f7", 18, "~", false],
                        //   ["f8", 19, "~", false],
                        //   ["f9", 20, "~", false],
                        //   ["f10", 21, "~", false],
                        //   ["f11", 23, "~", false],
                        //   ["f12", 24, "~", false],
                        //   ["prior", 5, "~", false],
                        //   ["next", 6, "~", false],
                        //  ["insert", 2, "~", false],
                        //   ["delete", 3, "~", false],
                        13 => .f3,
                        15 => .f5,
                        17 => .f6,
                        18 => .f7,
                        19 => .f8,
                        20 => .f9,
                        21 => .f10,
                        23 => .f11,
                        24 => .f12,
                        5 => .page_up,
                        6 => .page_down,
                        2 => .insert,
                        3 => .delete,
                        else => return .nomatch,
                    },
                    else => return .nomatch,
                },
                action,
                modifiers,
                csi.raw,
            );
        },
    }

    _ = base_layout_key; // autofix

    // const last_param = csi.parseParamAsWithSubParams(csi.parameter_count - 1);
    // const last_param_last_subparam = last_param.parameters[last_param.parameter_count - 1];

    // if (last_param_last_subparam.suffix == 0) {
    //     return .nomatch;
    // }
    // const unicode = last_param_last_subparam.int;

    // fmt.debug.print("csi: {}\n", .{unicode});

    // const first_param = csi.parseParamAsWithSubParams(0);
    // fmt.debug.print("first_param: {} {s}\n", .{ first_param, raw[1..] });

    // // Kitty keyboard protocol has this format:
    // // CSI unicode-key-code:alternate-key-codes ; modifiers:event-type ; text-as-codepoints u

    // // Parse first parameter which might contain codepoint and alternate key code
    // var unicode_key_code: u32 = 0;
    // var alternate_key_code: u32 = 0;
    // var has_alternate = false;

    // // Check if the first parameter contains a colon (unicode:alternate format)
    // if (std.mem.containsAtLeast(u8, csi.parameters[0], 1, ":")) {
    //     const parsed = csi.parseColonSeparated(0);
    //     unicode_key_code = parsed.before.int;
    //     alternate_key_code = parsed.after.int;
    //     has_alternate = true;
    // } else {
    //     // Simple codepoint
    //     unicode_key_code = csi.parseParamAsSimpleInt(0);
    // }

    // // Parse modifiers and event type from second parameter, if available
    // var modifiers: u8 = 0;
    // var event_type: u8 = 1; // Default is press event

    // if (csi.parameter_count > 1) {
    //     // Check if second parameter contains a colon (modifiers:event-type format)
    //     if (std.mem.containsAtLeast(u8, csi.parameters[1], 1, ":")) {
    //         const parsed = csi.parseColonSeparated(1);
    //         const mod_param = parsed.before.int;
    //         event_type = @truncate(parsed.after.int);

    //         // In kitty protocol, modifiers value is (actual modifiers + 1)
    //         if (mod_param > 0) {
    //             modifiers = @truncate(mod_param - 1);
    //         }
    //     } else {
    //         // Just modifiers, no event type
    //         const mod_param = csi.parseParamAsSimpleInt(1);
    //         if (mod_param > 0) {
    //             modifiers = @truncate(mod_param - 1);
    //         }
    //     }
    // }

    // // Parse text-as-codepoints from third parameter if available
    // var text_codepoint: u32 = 0;

    // if (csi.parameter_count > 2) {
    //     text_codepoint = csi.parseParamAsSimpleInt(2);
    // }

    // // Use the text codepoint if available, otherwise use the unicode key code
    // const final_codepoint = if (text_codepoint > 0) text_codepoint else unicode_key_code;

    // // Make sure we have a valid codepoint
    // if (final_codepoint == 0) {
    //     return .nomatch;
    // }

    // // Emit the key event
    // // NOTE: Zig doesn't have an event_type field, so we ignore that for now
    // // In a full implementation, we'd want to propagate the event type (press, repeat, release)
    // manager.emitCodepoint(@intCast(final_codepoint), modifiers, raw);
    return .{ .match = raw.len };
}
const KittySequence = @import("keys.zig").KittySequence;
fn expectKittySequence(allocator: std.mem.Allocator, comptime seq: KittySequence, comptime expected: []const u8) !void {
    var buf: [128]u8 = undefined;

    const actual = try seq.encode(&buf);
    // std.debug.print("actual: {s}\n", .{actual[1..]});
    try expectEvents(
        allocator,
        actual[1..],
        &.{actual},
        &.{expected},
    );
}
test "unicode" {
    try expectKittySequence(std.testing.allocator, .{
        .key = 'a',
        .final = 'u',
        .event = .press,
        .mods = .{
            .shift = true,
        },
    }, "[key 'a' 97 mod='shift']");

    try expectKittySequence(std.testing.allocator, .{
        .key = 'a',
        .final = 'u',
        .event = .press,
        .mods = .{
            .shift = true,
            .ctrl = true,
        },
    }, "[key 'a' 97 mod='shift+ctrl']");

    try expectKittySequence(std.testing.allocator, .{
        .key = 'a',
        .final = 'u',
        .event = .press,
    }, "[key 'a' 97]");

    try expectKittySequence(std.testing.allocator, .{
        .key = 'a',
        .final = 'u',
        .event = .release,
    }, "[key .release 'a' 97]");

    try expectKittySequence(std.testing.allocator, .{
        .key = 'a',
        .final = 'u',
        .event = .repeat,
    }, "[key .repeat 'a' 97]");
}

pub fn handleCsiCsi(manager: *AnyInputManager, buffer: []const u8, position: usize, intro_len: usize) Match {
    logger.info("try handleCsiCsi", .{});
    const ret = parseCsi(buffer, position, intro_len);
    const csi: RawCsi = switch (ret) {
        .partial => {
            if (manager.modeIsNot(.force)) {
                return .{ .partial = {} };
            }
            manager.emitFromCodepoint('[', '[', .press, Event.mod.ALT, buffer[position .. position + 1]);
            return .{ .match = position + 1 };
        },
        .nomatch => {
            return .nomatch;
        },
        .match => |raw_csi| raw_csi,
    };

    const match = switch (csi.cmd_byte) {
        'M', 'm' => blk: {
            if (csi.parameter_count < 3) {
                break :blk interpretNormalTrackingMouseEvent(manager, buffer, position, intro_len + 1);
            }

            // Handle SGR or URXVT mouse protocol
            break :blk interpretExtendedMouseEvent(manager, csi, buffer[position..]);
        },
        // Handle cursor position report
        'R' => interpretCursorPositionReport(manager, csi, buffer[position..]),
        'y' => interpretModeStatusReport(manager, csi, buffer[position..]),
        'u', 'A', 'B', 'C', 'D', 'E', 'F', 'H', 'P', 'Q', 'S', '~' => interpretUnicodeKey(manager, csi, buffer[position..]),
        else => return .nomatch,
    };

    switch (match) {
        .nomatch => {
            manager.emit(.{
                .data = .{
                    .unknown_sequence = {},
                },

                .raw = csi.raw,
                .modifiers = 0,
            });
            return .{ .match = csi.raw.len };
        },

        else => return match,
    }
}

// Handles SGR (1006) and URXVT (1015) mouse protocols
pub fn interpretExtendedMouseEvent(manager: *AnyInputManager, csi: RawCsi, raw: []const u8) Match {
    var mouse = Event.Mouse{
        .extended = .{
            .button = .none,
            .action = .press,
            .x = 0,
            .y = 0,
        },
    };

    if (csi.parameter_count < 3) {
        return .nomatch;
    }

    // Parse the button and modifier information
    const button_param = csi.parseParamAsSimpleInt(0);
    // X and Y coordinates are 1-based in the protocol, convert to 0-based
    const x = csi.parseParamAsSimpleInt(1) -| 1; // Saturating subtraction to avoid underflow
    const y = csi.parseParamAsSimpleInt(2) -| 1;

    // Set the coordinates
    mouse.extended.x = @truncate(x);
    mouse.extended.y = @truncate(y);

    // Extract modifiers (bits 2-4)
    const modifiers: u8 = @truncate((button_param & 0x1c) >> 2);

    // Handle the button value - clear modifier bits
    var button_value: u32 = button_param & ~@as(u32, 0x1c);

    // Check if this is a release event (SGR uses 'm' as the cmd_byte for release)
    const is_release = (csi.cmd_byte == 'm');

    // Set the action based on the SGR release flag or the encoded button value
    if (is_release) {
        mouse.extended.action = .release;
    } else if (button_value & 0x20 != 0) {
        mouse.extended.action = .motion;
        button_value &= ~@as(u32, 0x20);
    } else {
        mouse.extended.action = .press;
    }

    // Set the button based on the button value
    if (button_value & 0x40 != 0) { // Wheel or tilt buttons (4-7)
        button_value &= ~@as(u32, 0x40);

        // For wheel events, we set the button to wheel and use specific actions
        mouse.extended.button = .wheel;

        // Determine wheel direction from the button bits
        mouse.extended.action = switch (button_value & 0x03) {
            0 => .wheel_up, // Button 4 (wheel up)
            1 => .wheel_down, // Button 5 (wheel down)
            2 => .wheel_left, // Button 6 (wheel tilt left)
            3 => .wheel_right, // Button 7 (wheel tilt right)
            else => .press, // fallback (shouldn't happen)
        };
    } else if (button_value & 0x80 != 0) { // Higher buttons (8-11)
        button_value &= ~@as(u32, 0x80);

        mouse.extended.button = switch (button_value & 0x03) {
            0 => .button8,
            1 => .button9,
            2 => .button10,
            3 => .button11,
            else => .none,
        };
    } else {
        // Normal buttons (0-3)
        mouse.extended.button = switch (button_value & 0x03) {
            0 => .left,
            1 => .middle,
            2 => .right,
            3 => .none, // No button or release
            else => .none,
        };
    }

    manager.emitMouse(mouse, modifiers, raw);
    return .{ .match = raw.len };
}

// Handles cursor position reports (CSI row;col R)
pub fn interpretCursorPositionReport(manager: *AnyInputManager, csi: RawCsi, raw: []const u8) Match {
    // Cursor position reports require at least 2 parameters: row and column
    if (csi.parameter_count < 2) {
        return .nomatch;
    }
    if (csi.initial_byte != '?') {
        return .nomatch;
    }

    const row = csi.parseParamAsSimpleInt(0) -| 1; // First param is row
    const col = csi.parseParamAsSimpleInt(1) -| 1; // Second param is column

    manager.emit(.{
        .data = .{ .cursor_report = .{ .row = @truncate(row), .col = @truncate(col) } },
        .modifiers = 0,
        .raw = raw,
    });
    return .{ .match = raw.len };
}

test "interpretX10MouseEvent" {
    try expectEvents(
        std.testing.allocator,
        "left",
        &.{"\x1b[M" ++ [_]u8{ 32, 232, 232 }},
        &.{"[mouse .left_press (x=200 y=200)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "middle",
        &.{"\x1b[M" ++ [_]u8{ 33, 232, 232 }},
        &.{"[mouse .middle_press (x=200 y=200)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "right",
        &.{"\x1b[M" ++ [_]u8{ 34, 232, 232 }},
        &.{"[mouse .right_press (x=200 y=200)]"},
    );

    try expectEvents(
        std.testing.allocator,
        "release",
        &.{"\x1b[M" ++ [_]u8{ 35, 232, 232 }},
        &.{"[mouse .release (x=200 y=200)]"},
    );

    // Test wheel mice events - note: keeping original names for normal tracking mode
    try expectEvents(
        std.testing.allocator,
        "wheel forward",
        &.{"\x1b[M" ++ [_]u8{ 32 + 64, 232, 232 }},
        &.{"[mouse .wheel_forward (x=200 y=200)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "wheel back",
        &.{"\x1b[M" ++ [_]u8{ 33 + 64, 232, 232 }},
        &.{"[mouse .wheel_back (x=200 y=200)]"},
    );

    // Test wheel tilt events
    try expectEvents(
        std.testing.allocator,
        "wheel tilt right",
        &.{"\x1b[M" ++ [_]u8{ 34 + 64, 232, 232 }},
        &.{"[mouse .wheel_tilt_right (x=200 y=200)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "wheel tilt left",
        &.{"\x1b[M" ++ [_]u8{ 35 + 64, 232, 232 }},
        &.{"[mouse .wheel_tilt_left (x=200 y=200)]"},
    );

    // Test higher buttons (8-11)
    try expectEvents(
        std.testing.allocator,
        "button 8 (with 128 flag)",
        &.{"\x1b[M" ++ [_]u8{ 32 + 128, 232, 232 }},
        &.{"[mouse .left_press (x=200 y=200)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "button 9 (with 128 flag)",
        &.{"\x1b[M" ++ [_]u8{ 33 + 128, 232, 232 }},
        &.{"[mouse .middle_press (x=200 y=200)]"},
    );

    // Test with modifiers
    try expectEvents(
        std.testing.allocator,
        "left with shift",
        &.{"\x1b[M" ++ [_]u8{ 32 + 4, 232, 232 }},
        &.{"[mouse .left_press (x=200 y=200) mod='shift']"},
    );
    try expectEvents(
        std.testing.allocator,
        "wheel forward with ctrl",
        &.{"\x1b[M" ++ [_]u8{ 32 + 64 + 16, 232, 232 }},
        &.{"[mouse .wheel_forward (x=200 y=200) mod='ctrl']"},
    );
}

test "interpretExtendedMouseEvents" {
    // Test SGR protocol (1006)
    try expectEvents(
        std.testing.allocator,
        "SGR left press",
        &.{"\x1b[<0;100;100M"},
        &.{"[mouse .extended .press .left (x=99 y=99)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR right press",
        &.{"\x1b[<2;50;60M"},
        &.{"[mouse .extended .press .right (x=49 y=59)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR left release",
        &.{"\x1b[<0;25;30m"},
        &.{"[mouse .extended .release .left (x=24 y=29)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR wheel up",
        &.{"\x1b[<64;75;80M"},
        &.{"[mouse .extended .wheel_up .wheel (x=74 y=79)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR wheel down",
        &.{"\x1b[<65;45;50M"},
        &.{"[mouse .extended .wheel_down .wheel (x=44 y=49)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR wheel left",
        &.{"\x1b[<66;120;130M"},
        &.{"[mouse .extended .wheel_left .wheel (x=119 y=129)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR wheel right",
        &.{"\x1b[<67;90;95M"},
        &.{"[mouse .extended .wheel_right .wheel (x=89 y=94)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR with shift modifier",
        &.{"\x1b[<4;10;15M"},
        &.{"[mouse .extended .press .left (x=9 y=14) mod='shift']"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR with ctrl modifier",
        &.{"\x1b[<16;30;35M"},
        &.{"[mouse .extended .press .left (x=29 y=34) mod='ctrl']"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR with alt modifier",
        &.{"\x1b[<8;50;55M"},
        &.{"[mouse .extended .press .left (x=49 y=54) mod='alt']"},
    );

    // Test motion events
    try expectEvents(
        std.testing.allocator,
        "SGR motion with left button",
        &.{"\x1b[<32;60;65M"},
        &.{"[mouse .extended .motion .left (x=59 y=64)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR motion with right button",
        &.{"\x1b[<34;70;75M"},
        &.{"[mouse .extended .motion .right (x=69 y=74)]"},
    );

    // Test higher buttons
    try expectEvents(
        std.testing.allocator,
        "SGR button 8",
        &.{"\x1b[<128;40;45M"},
        &.{"[mouse .extended .press .button8 (x=39 y=44)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "SGR button 9",
        &.{"\x1b[<129;50;55M"},
        &.{"[mouse .extended .press .button9 (x=49 y=54)]"},
    );

    // Test URXVT protocol (1015)
    try expectEvents(
        std.testing.allocator,
        "URXVT left press",
        &.{"\x1b[0;100;100M"},
        &.{"[mouse .extended .press .left (x=99 y=99)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "URXVT right press",
        &.{"\x1b[2;50;60M"},
        &.{"[mouse .extended .press .right (x=49 y=59)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "URXVT wheel up",
        &.{"\x1b[64;75;80M"},
        &.{"[mouse .extended .wheel_up .wheel (x=74 y=79)]"},
    );
    try expectEvents(
        std.testing.allocator,
        "URXVT with shift modifier",
        &.{"\x1b[4;10;15M"},
        &.{"[mouse .extended .press .left (x=9 y=14) mod='shift']"},
    );
}

test "interpretCursorPositionReport" {
    try expectEvents(
        std.testing.allocator,
        "Cursor position report",
        &.{"\x1b[?10;20R"},
        &.{"[mouse .cursor_report (row=9 col=19)]"},
    );

    try expectEvents(
        std.testing.allocator,
        "Cursor position with leading zero",
        &.{"\x1b[?01;05R"},
        &.{"[mouse .cursor_report (row=0 col=4)]"},
    );

    try expectEvents(
        std.testing.allocator,
        "Cursor position at origin",
        &.{"\x1b[?1;1R"},
        &.{"[mouse .cursor_report (row=0 col=0)]"},
    );

    try expectEvents(
        std.testing.allocator,
        "Cursor position with leading zero",
        &.{"\x1b[?1;05R"},
        &.{"[mouse .cursor_report (row=0 col=4)]"},
    );
}

test "interpretModeStatusReport" {
    // Test form 1: CSI?<mode>;<value>$y
    // try expectEvents(
    //     std.testing.allocator,
    //     "Mode status report - with ? prefix",
    //     &.{"\x1b[?25;60$y"},
    //     &.{"[mode_report (mode=63 value1=25 value2=60)]"},
    // );

    // // Test form 2: CSI<mode>;<value>$y
    // try expectEvents(
    //     std.testing.allocator,
    //     "Mode status report - standard form",
    //     &.{"\x1b[100;45$y"},
    //     &.{"[mode_report (mode=0 value1=100 value2=45)]"},
    // );

    // // Test with $ directly after parameter
    // try expectEvents(
    //     std.testing.allocator,
    //     "Mode status report - $ after parameter",
    //     &.{"\x1b[100;45$y"},
    //     &.{"[mode_report (mode=0 value1=100 value2=45)]"},
    // );

    // // Test with space between parameter and $
    // try expectEvents(
    //     std.testing.allocator,
    //     "Mode status report - space before $",
    //     &.{"\x1b[100;45 $y"},
    //     &.{"[mode_report (mode=0 value1=100 value2=45)]"},
    // );

    // // Test with larger values
    // try expectEvents(
    //     std.testing.allocator,
    //     "Mode status report - with larger values",
    //     &.{"\x1b[1024;255$y"},
    //     &.{"[mode_report (mode=0 value1=1024 value2=255)]"},
    // );
}

// test "interpretUnicodeKey" {
//     // Test basic Unicode key with no modifiers
//     try expectEvents(
//         std.testing.allocator,
//         "Unicode key - basic A",
//         &.{
//             "\x1b[65u",
//         },
//         &.{
//             "[codepoint 'A']",
//         },
//     );

//     // Test Unicode key with shift modifier (1)
//     try expectEvents(
//         std.testing.allocator,
//         "Unicode key - A with Shift",
//         &.{"\x1b[65;2u"},
//         &.{"[codepoint 'A' mod='shift']"},
//     );

//     // Test Unicode key with alt modifier (2)
//     try expectEvents(
//         std.testing.allocator,
//         "Unicode key - B with Alt",
//         &.{"\x1b[66;3u"},
//         &.{"[codepoint 'B' mod='alt']"},
//     );

//     // Test Unicode key with ctrl modifier (4)
//     try expectEvents(
//         std.testing.allocator,
//         "Unicode key - C with Ctrl",
//         &.{"\x1b[67;5u"},
//         &.{"[codepoint 'C' mod='ctrl']"},
//     );

//     // Test Unicode key with multiple modifiers (shift+alt = 3)
//     try expectEvents(
//         std.testing.allocator,
//         "Unicode key - D with Shift+Alt",
//         &.{"\x1b[68;4u"},
//         &.{"[codepoint 'D' mod='shift|alt']"},
//     );

//     // Test higher Unicode codepoint
//     try expectEvents(
//         std.testing.allocator,
//         "Unicode key - emoji",
//         &.{"\x1b[128512u"}, // 😀 U+1F600
//         &.{"[codepoint '😀']"},
//     );

//     // Kitty protocol tests

//     // Test with alternate key code
//     try expectEvents(
//         std.testing.allocator,
//         "Kitty - Unicode with alternate",
//         &.{"\x1b[97:65u"}, // 'a' with alternate 'A'
//         &.{"[codepoint 'a']"},
//     );

//     // Test with event type (press)
//     try expectEvents(
//         std.testing.allocator,
//         "Kitty - with press event type",
//         &.{"\x1b[65;2:1u"}, // 'A' with shift modifier and press event
//         &.{"[codepoint 'A' mod='shift']"},
//     );

//     // Test with event type (repeat)
//     try expectEvents(
//         std.testing.allocator,
//         "Kitty - with repeat event type",
//         &.{"\x1b[65;2:2u"}, // 'A' with shift modifier and repeat event
//         &.{"[codepoint 'A' mod='shift']"},
//     );

//     // Test with event type (release)
//     try expectEvents(
//         std.testing.allocator,
//         "Kitty - with release event type",
//         &.{"\x1b[65;2:3u"}, // 'A' with shift modifier and release event
//         &.{"[codepoint 'A' mod='shift']"},
//     );

//     // Test with text codepoints
//     try expectEvents(
//         std.testing.allocator,
//         "Kitty - with text codepoints",
//         &.{"\x1b[97;2;65u"}, // 'a' with shift modifier, text is 'A'
//         &.{"[codepoint 'A' mod='shift']"},
//     );

//     // Test full Kitty format
//     try expectEvents(
//         std.testing.allocator,
//         "Kitty - full format",
//         &.{"\x1b[97:98;2:1;65u"}, // 'a' with alternate 'b', shift, press event, text 'A'
//         &.{"[codepoint 'A' mod='shift']"},
//     );
// }

pub fn handleCsi(manager: *AnyInputManager, buffer: []const u8, position: usize) Match {
    logger.info("try handleCsi", .{});
    if (buffer.len - position < 2) {
        return .nomatch;
    }
    std.debug.assert(buffer[position] == '\x1b');

    switch (buffer[position]) {
        0x1b => switch (buffer[position + 1]) {
            'O' => {
                return handleSs3(manager, buffer, position, 2);
            },
            'P', ']' => {
                return handleCtrlString(manager, buffer, position, 2);
            },
            '[' => {
                return handleCsiCsi(manager, buffer, position, 2);
            },
            else => return .nomatch,
        },
        0x8f => {
            std.debug.panic("todo handleSs3", .{});
            return handleSs3(manager, buffer, position, 1);
        },
        0x90, 0x92 => {
            return handleCtrlString(manager, buffer, position, 1);
        },
        0x9b => {
            return handleCsiCsi(manager, buffer, position, 2);
        },

        else => {},
    }
    if (manager.modeIs(.force)) {
        manager.emitNamed(.escape, .press, 0, buffer[position .. position + 1]);
        manager.setMode(.normal);
        return .{ .match = 1 };
    }
    return .{ .partial = {} };
}
test "csi" {}

test "dcs" {
    // Assuming there's a helper for creating a test input manager
    // This is just a skeleton test to verify the integration with the DCS parser
    const dcs_sequence = "\x1bP$q\"p\x1b\\"; // Request DECSCL status

    // TODO: When more detailed tests are added, implement actual
    // testing of the handleCtrlString function with a DCS sequence

    // For now, just verify the DCS parser works correctly
    const dcs = Dcs.parse(dcs_sequence);
    try std.testing.expect(dcs != null);
    try std.testing.expectEqual(dcs.?.parameter_selector, .request_status_string);
    try std.testing.expectEqualSlices(u8, dcs.?.parameter_text, "\"p");
    try std.testing.expectEqual(dcs.?.status_request_type, .decscl);
}
