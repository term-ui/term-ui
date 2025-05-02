const std = @import("std");
const Allocator = std.mem.Allocator;
pub fn Trie(T: type) type {
    return struct {
        /// Root node of the trie
        root: Node,
        /// Arena allocator used for all memory allocations
        arena: std.heap.ArenaAllocator,
        const Self = @This();
        /// Node in the trie
        const Node = struct {
            children: std.AutoArrayHashMapUnmanaged(u8, *Node) = .{},
            value: ?T = null,
            // is_end_of_word: bool = false,
        };
        /// Create a new Trie with the given parent allocator
        pub fn init(parent_allocator: Allocator) Self {
            return Self{
                .root = .{},
                .arena = std.heap.ArenaAllocator.init(parent_allocator),
            };
        }

        /// Free all memory used by the trie
        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        /// Insert a string into the trie
        pub fn insert(self: *Self, key: []const u8, value: T) !void {
            var current = &self.root;

            for (key) |c| {
                const gop = try current.children.getOrPut(self.arena.allocator(), c);
                if (!gop.found_existing) {
                    gop.value_ptr.* = try self.arena.allocator().create(Node);
                    gop.value_ptr.*.* = .{};
                }
                current = gop.value_ptr.*;
            }

            current.value = value;
        }

        /// Check if a string exists in the trie
        pub fn search(self: Self, key: []const u8) bool {
            var current = &self.root;

            for (key) |c| {
                const next = current.children.get(c);
                if (next) |next_node| {
                    current = next_node;
                } else {
                    return false;
                }
            }

            return current.value != null;
        }
        pub fn get(self: Self, key: []const u8) ?*const Node {
            var current = &self.root;

            for (key) |c| {
                const next = current.children.get(c);
                if (next) |next_node| {
                    current = next_node;
                } else {
                    return null;
                }
            }
            return current;
        }

        /// Check if any string with the given prefix exists in the trie
        pub fn startsWith(self: Self, prefix: []const u8) bool {
            var current = &self.root;

            for (prefix) |c| {
                const next = current.children.get(c);
                if (next) |next_node| {
                    current = next_node;
                } else {
                    return false;
                }
            }

            return true;
        }
    };
}

test "trie" {
    var trie = Trie(void).init(std.testing.allocator);
    defer trie.deinit();

    try trie.insert("hello", {});
    try trie.insert("world", {});
    try std.testing.expect(trie.search("hello"));
    try std.testing.expect(trie.search("world"));
    try std.testing.expect(!trie.search("hell"));
    try std.testing.expect(trie.startsWith("he"));
    try std.testing.expect(trie.startsWith("wo"));
    try std.testing.expect(trie.search("world"));
    const node = trie.get("hell");
    try std.testing.expect(node != null);
    try std.testing.expect(node.?.value == null);
}
