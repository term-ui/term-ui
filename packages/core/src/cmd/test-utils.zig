const std = @import("std");
const Collector = @import("input/manager.zig").Collector;
const TermInfoHandler = @import("handle-term-info.zig");
const handleRawBuffer = @import("input.zig").handleRawBuffer;
const TermInfo = @import("terminfo/main.zig").TermInfo;
const escape = @import("input/manager.zig").escape;

fn readTermInfo(allocator: std.mem.Allocator, comptime name: []const u8) !TermInfoHandler {
    var file = try std.fs.cwd().openFile("src/cmd/test-data/" ++ name, .{});
    defer file.close();
    const term_info = try TermInfo.initFromFile(std.testing.allocator, file);
    defer term_info.deinit();
    var iter = term_info.strings.iter();
    var handler = TermInfoHandler.init(allocator);
    while (iter.next()) |item| {
        // std.debug.print("inserting {s} ", .{@tagName(item.capability)});
        // try escape(std.io.getStdErr().writer().any(), item.value);
        // std.debug.print("\n", .{});
        try handler.trie.insert(item.value, item.capability);
    }
    return handler;
}

pub fn expectEvents(allocator: std.mem.Allocator, case: []const u8, buffers: []const []const u8, expected: []const []const u8) !void {
    var collector = Collector.init(allocator);
    defer collector.deinit();
    var manager = collector.manager().any();
    var term_info = try readTermInfo(allocator, "xterm-ghostty");
    // var term_info = TermInfoHandler.init(allocator);

    defer term_info.deinit();
    manager.term_info_driver = &term_info;

    var actual_str = std.ArrayList(u8).init(allocator);
    defer actual_str.deinit();
    var actual_str_writer = actual_str.writer().any();
    var expected_str = std.ArrayList(u8).init(allocator);
    defer expected_str.deinit();
    var expected_str_writer = expected_str.writer().any();

    var buffered = std.ArrayList(u8).init(allocator);
    defer buffered.deinit();
    var position: usize = 0;
    for (buffers) |buf| {
        try buffered.appendSlice(buf);
        const consumed = handleRawBuffer(
            &manager,
            buffered.items,
            position,
        );
        std.debug.print("consumed {d} ~ {d} of {d}\n", .{ position, position + consumed, buffered.items.len });
        position += consumed;
    }

    for (collector.events.items) |event| {
        try actual_str_writer.print("{}\n", .{event});
    }
    for (expected) |exp| {
        try expected_str_writer.print("{s}\n", .{exp});
    }

    std.testing.expectEqualStrings(expected_str.items, actual_str.items) catch |err| {
        std.debug.print("Failed to match '{s}'\n", .{case});
        return err;
    };
}
