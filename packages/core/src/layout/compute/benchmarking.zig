const std = @import("std");
const time = std.time;

pub fn printTiming(label: []const u8, ns: anytype) void {
    if (ns < 1000) {
        std.debug.print("{s}: {d:.0} ns/op\n", .{ label, ns });
        return;
    }

    const us = ns / 1000;
    if (us < 1000) {
        std.debug.print("{s}: {d:.3} us/op\n", .{ label, us });
        return;
    }

    const ms = us / 1000;
    if (ms < 1000) {
        std.debug.print("{s}: {d:.3} ms/op\n", .{ label, ms });
        return;
    }

    const s = ms / 1000;
    if (s < 1000) {
        std.debug.print("{s}: {d:.3} s/op\n", .{ label, s });
        return;
    }
}

const bench_cap = time.ns_per_s / 5;

// run the function for min(100000 loops, ~0.2 seconds) or at least once, whichever is longer
pub fn bench(comptime name: []const u8, f: anytype, m: usize) !void {
    var timer = try time.Timer.start();

    var loops: usize = 0;
    while (loops < m) : (loops += 1) {
        // this would either take a void function (easy with local functions)
        // or comptime varargs in the general args
        try f();
        // std.debug.print
        // if (loops > m) {
        //     break;
        // }
    }

    const ns: f64 = @floatFromInt(timer.lap() / loops);

    // const mgn = std.math.log10(loops);
    // var loop_mgn: usize = 10;
    // var i: usize = 0;
    // while (i < mgn) : (i += 1) {
    //     loop_mgn *= 10;
    // }

    std.debug.print("{s}: {d} loops\n   ", .{ name, loops });
    printTiming("", ns);
}
