const std = @import("std");
const ArrayList = std.ArrayList;
const Layout = @import("../tree/Layout.zig");
const Style = @import("../tree/Style.zig");
const test_allocator = std.testing.allocator;
pub fn dumpStruct(st: anytype) void {
    std.debug.print("[{s}]\n", .{@typeName(@TypeOf(st))});
    innerDumpStruct(st, 1);
}

pub inline fn innerDumpStruct(st: anytype, indent: usize) void {
    const indent_str = comptime blk: {
        var arr: [indent * 4]u8 = undefined;
        for (0..indent * 4) |i| {
            arr[i] = ' ';
        }
        break :blk arr;
    };

    // std.builtin.Type
    inline for (std.meta.fields(@TypeOf(st))) |f| {
        switch (@typeInfo(f.type)) {
            .Enum => {
                std.debug.print("{s}[{s}] = {any}\n", .{
                    indent_str,
                    f.name,
                    @field(st, f.name),
                });
            },
            .Struct => {
                std.debug.print("{s}[{s}]\n", .{
                    indent_str,
                    f.name,
                });
                innerDumpStruct(@field(st, f.name), indent + 1);
            },
            else => {
                switch (f.type) {
                    u8, u16, u32, u64, i8, i16, i32, i64, f32, comptime_float => {
                        std.debug.print("{s}[{s}: {any}] = {d}\n", .{
                            indent_str,
                            f.name,
                            f.type,
                            @field(st, f.name),
                        });
                    },
                    else => {
                        std.debug.print("{s}[{s}: {any}] = {any}\n", .{
                            indent_str,
                            f.name,
                            f.type,
                            @field(st, f.name),
                        });
                    },
                }
                // std.debug.print("{s}[{s}: {any}] = {any}\n", .{ indent_str, f.name, f.type, @field(st, f.name) });
            },
        }
        // std.debug.print("{s}[{s}: {any}] = {any}", .{ " ", f.name, f.type, @field(st, f.name) });
        // @field(st, f.name) = @as(f.type, @field(b, f.name));
    }
}
pub fn genStructFmt(writer: anytype, v: anytype, comptime indent: usize) !void {
    const T = @TypeOf(v);

    const single_indent = "    ";
    switch (@typeInfo(T)) {
        .Struct => {
            const indent_s = single_indent ** indent;
            const name = @typeName(T);
            try writer.writeAll(name ++ " {\n");
            inline for (std.meta.fields(T)) |f| {
                try writer.writeAll(indent_s ++ single_indent ++ f.name ++ " = ");

                try genStructFmt(writer, @field(v, f.name), indent + 1);
                try writer.writeAll("\n");
            }
            try writer.writeAll(indent_s ++ "}");
        },
        .Optional => {},
        .Int, .Float, .ComptimeFloat, .ComptimeInt => {
            try std.fmt.format(writer, "{d}", .{v});
        },
        else => {
            try std.fmt.format(writer, "{any}", .{v});
        },
    }
    // const f = @typeOf(v);
    // inline for (std.meta.fields(@TypeOf(v))) |f| {

    // switch (@typeInfo(f.type)) {
    //     .Enum => {
    //         try writer.writeAll(indent_s ++ name ++ " = ");
    //         try std.fmt.format(writer, "\x1b[1;31m{any}\x1b[0m\n", .{value});
    //
    //         // @field(v, f.name);
    //     },
    //     .Struct => {
    //         try writer.writeAll(indent_s ++ name ++ " = " ++ ty ++ " {\n");
    //         try genStructFmt(writer, value, indent + 1);
    //         try writer.writeAll(indent_s ++ "}\n");
    //         // try writer.writeAll("\n");
    //     },
    //     .Union => {
    //         try writer.writeAll(indent_s ++ name ++ " = ");
    //         try std.fmt.format(writer, "\x1b[1;31m{any}\x1b[0m\n", .{value});
    //     },
    //     .Int, .Float, .ComptimeFloat, .ComptimeInt => {
    //         try writer.writeAll(indent_s ++ name ++ " = " ++ ty ++ " = ");
    //         try std.fmt.format(writer, "\x1b[1;36m{d}\x1b[0m\n", .{value});
    //     },
    //     .Optional => |info| {
    //         switch (info.child) {
    //             .Int, .Float, .ComptimeFloat, .ComptimeInt => {
    //                 try writer.writeAll(indent_s ++ name ++ " = " ++ ty ++ " = ");
    //                 try std.fmt.format(writer, "\x1b[1;36m{d}\x1b[0m\n", .{value});
    //             },
    //             else => {
    //                 try writer.writeAll(indent_s ++ name ++ " = " ++ ty ++ " = ");
    //                 try std.fmt.format(writer, "\x1b[1;31m{any}\x1b[0m\n", .{value});
    //             },
    //         }
    //     },
    //     else => {
    //         try writer.writeAll(indent_s ++ name ++ ": " ++ ty ++ " = ");
    //         try std.fmt.format(writer, "\x1b[1;31m{any}\x1b[0m\n", .{value});
    //         // try writer.writeAll("\n");
    //     },
    // }
    // }
}
pub fn formatStruct(writer: anytype, s: anytype) void {
    // inline for (std.meta.fields(@TypeOf(s))) |f| {
    // const value = @field(s, f.name);
    genStructFmt(writer, s, 0) catch return;
    // }
    // return fmt;
}
const io = @import("std").io;
test "debug fn" {
    const stderr = io.getStdErr().writer();
    formatStruct(stderr, Style{});
    // std.debug.print("{any}", .{.{ .x = 1.3, .z = .{ .a = "b" } }});
    // debug("Hello from debug", .{ 1, 2, .{3} });
}
