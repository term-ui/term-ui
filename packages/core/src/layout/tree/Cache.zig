const LayoutOutput = @import("../compute/compute_constants.zig").LayoutOutput;
const RunMode = @import("../compute/compute_constants.zig").RunMode;
const AvailableSpace = @import("../compute/compute_constants.zig").AvailableSpace;
const Point = @import("../point.zig").Point;
const Cache = @This();

fn CacheEntry(comptime T: type) type {
    return struct {
        known_dimensions: Point(?f32),
        available_space: Point(AvailableSpace),
        content: T,
    };
}

const CACHE_SIZE: usize = 9;
final_layout_entry: ?CacheEntry(LayoutOutput) = null,
measure_entries: [CACHE_SIZE]?CacheEntry(Point(f32)) = [_]?CacheEntry(Point(f32)){null} ** CACHE_SIZE,

pub fn computeCacheSlot(known_dimensions: Point(?f32), available_space: Point(AvailableSpace)) usize {
    const has_known_width = known_dimensions.x != null;
    const has_known_height = known_dimensions.y != null;
    // Slot 0: Both known_dimensions were set
    if (has_known_width and has_known_height) {
        return 0;
    }

    // Slot 1: width but not height known_dimension was set and the other dimension was either a MaxContent or Definite available space constraint
    // Slot 2: width but not height known_dimension was set and the other dimension was a MinContent constraint

    if (has_known_width and !has_known_height) {
        if (available_space.y == .min_content) {
            return 2;
        }
        return 1;
    }

    // Slot 3: height but not width known_dimension was set and the other dimension was either a MaxContent or Definite available space constraint
    // Slot 4: height but not width known_dimension was set and the other dimension was a MinContent constraint
    if (has_known_height and !has_known_width) {
        if (available_space.x == .min_content) {
            return 4;
        }
        return 3;
    }

    // Slots 5-8: Neither known_dimensions were set and:
    switch (available_space.x) {
        .max_content, .definite => {
            switch (available_space.y) {
                // Slot 5: x-axis available space is MaxContent or Definite and y-axis available space is MaxContent or Definite
                .max_content, .definite => {
                    return 5;
                },
                // Slot 6: x-axis available space is MaxContent or Definite and y-axis available space is MinContent
                .min_content => {
                    return 6;
                },
            }
        },
        .min_content => {
            switch (available_space.y) {
                // Slot 7: x-axis available space is MinContent and y-axis available space is MaxContent or Definite
                .max_content, .definite => {
                    return 7;
                },
                // Slot 8: x-axis available space is MinContent and y-axis available space is MinContent
                .min_content => {
                    return 8;
                },
            }
        },
    }
}
pub fn get(self: *Cache, known_dimensions: Point(?f32), available_space: Point(AvailableSpace), run_mode: RunMode) ?LayoutOutput {
    switch (run_mode) {
        .perform_layout => {
            const entry = self.final_layout_entry orelse return null;
            const cached_size = entry.content.size;
            if ((known_dimensions.x == entry.known_dimensions.x or known_dimensions.x == cached_size.x) and
                (known_dimensions.y == entry.known_dimensions.y or known_dimensions.y == cached_size.y) and
                (known_dimensions.x != null or entry.available_space.x.isRoughlyEqual(available_space.x)) and
                (known_dimensions.y != null or entry.available_space.y.isRoughlyEqual(available_space.y)))
            {
                return entry.content;
            }
            return null;
        },
        .compute_size => {
            for (self.measure_entries) |entry_option| {
                const entry = entry_option orelse continue;
                const cached_size = entry.content;
                if ((known_dimensions.x == entry.known_dimensions.x or known_dimensions.x == cached_size.x) and
                    (known_dimensions.y == entry.known_dimensions.y or known_dimensions.y == cached_size.y) and
                    (known_dimensions.x != null or entry.available_space.x.isRoughlyEqual(available_space.x)) and
                    (known_dimensions.y != null or entry.available_space.y.isRoughlyEqual(available_space.y)))
                {
                    return LayoutOutput{ .size = cached_size };
                }
            }
            return null;
        },
        .perform_hidden_layout => {
            return null;
        },
    }
}

pub fn store(self: *Cache, known_dimensions: Point(?f32), available_space: Point(AvailableSpace), run_mode: RunMode, layout_output: LayoutOutput) void {
    switch (run_mode) {
        .perform_layout => {
            self.final_layout_entry = .{
                .known_dimensions = known_dimensions,
                .available_space = available_space,
                .content = layout_output,
            };
        },
        .compute_size => {
            const cache_slot = computeCacheSlot(known_dimensions, available_space);
            self.measure_entries[cache_slot] = .{
                .known_dimensions = known_dimensions,
                .available_space = available_space,
                .content = layout_output.size,
            };
        },
        .perform_hidden_layout => {},
    }
}

pub fn clear(self: *Cache) void {
    self.final_layout_entry = null;
    self.measure_entries = [_]?CacheEntry(Point(f32)){null} ** CACHE_SIZE;
}

pub fn isEmpty(self: *Cache) bool {
    if (self.final_layout_entry != null) {
        return false;
    }
    for (self.measure_entries) |entry| {
        if (entry != null) {
            return false;
        }
    }

    return true;
}
