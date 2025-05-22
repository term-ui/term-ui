const xml = @import("../xml.zig");
const std = @import("std");
const Tree = @import("../tree/Tree.zig");

pub const Options = struct {
    ignore_empty_text: bool = true,
    trim_text: bool = true,
    split_lines: bool = true,
};

pub fn docFromXml(allocator: std.mem.Allocator, xml_string: []const u8, options: Options) !Tree {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const doc = try xml.parse(arena_allocator, xml_string);
    var tree = try Tree.init(allocator);
    errdefer tree.deinit();
    _ = try nodeFromXmlElement(&tree, doc.root, options);
    return tree;
}

const TreeFromXmlError = error{
    OutOfMemory,
    NotFound,
    HierarchyRequestError,
    NotFoundError,
    Overflow,
    InvalidCharacter,
    NotInTheSameTree,
    OutOfBounds,
    StartAfterEnd,
};

fn isEmpty(str: []const u8) bool {
    for (str) |c| {
        switch (c) {
            ' ', '\n', '\t' => continue,
            else => return false,
        }
    }
    return true;
}
fn trimText(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \n\t\r");
}

fn nodeFromXmlElement(tree: *Tree, element: *xml.Element, options: Options) TreeFromXmlError!Tree.Node.NodeId {
    const node_id = try tree.createNode();

    for (element.children) |child| {
        switch (child) {
            .char_data => {
                if (options.ignore_empty_text and isEmpty(child.char_data)) {
                    continue;
                }
                if (options.split_lines) {
                    var iter = std.mem.splitScalar(u8, child.char_data, '\n');

                    while (iter.next()) |line| {
                        const text_node_id = try tree.createTextNode(if (options.trim_text) trimText(line) else line);
                        _ = try tree.appendChild(node_id, text_node_id);
                    }
                } else {
                    const text_node_id = try tree.createTextNode(if (options.trim_text) trimText(child.char_data) else child.char_data);
                    _ = try tree.appendChild(node_id, text_node_id);
                }
            },
            .comment => {
                // ignore
            },
            .element => {
                const child_id = try nodeFromXmlElement(tree, child.element, options);
                var child_node = tree.getNode(child_id);
                if (std.mem.eql(u8, child.element.tag, "span")) {
                    child_node.styles.display = .{ .outside = .@"inline", .inside = .flow };
                } else if (std.mem.eql(u8, child.element.tag, "strong") or std.mem.eql(u8, child.element.tag, "b")) {
                    child_node.styles.display = .{ .outside = .@"inline", .inside = .flow };
                    child_node.styles.font_weight = .bold;
                } else if (std.mem.eql(u8, child.element.tag, "em") or std.mem.eql(u8, child.element.tag, "i")) {
                    child_node.styles.display = .{ .outside = .@"inline", .inside = .flow };
                    child_node.styles.font_style = .italic;
                }
                _ = try tree.appendChild(node_id, child_id);
            },
        }
    }
    return node_id;
}
test "treeFromXml" {
    var tree = try docFromXml(std.testing.allocator, "<div>Hello, world!</div>", .{});
    defer tree.deinit();
    const stderr = std.io.getStdErr().writer().any();
    try tree.print(stderr);
}
