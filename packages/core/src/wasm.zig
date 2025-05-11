const Tree = @import("layout/tree/Tree.zig");
const Style = @import("layout/tree/Style.zig");
const std = @import("std");
const parsers = @import("styles/styles.zig");
const Renderer = @import("renderer/Renderer.zig");
const fmt = @import("fmt.zig");
const TermInfo = @import("cmd/terminfo/main.zig").TermInfo;
const InputManager = @import("cmd/input/manager.zig");
const builtin = @import("builtin");
const logger = std.log.scoped(.wasm);

const is_debug = builtin.mode == .Debug;

const is_wasm = @import("builtin").target.cpu.arch.isWasm();

pub const std_options: std.Options = .{
    .logFn = wasmLog,
    .log_level = if (is_debug) .debug else .err,
};

extern fn externalLog(message: [*:0]u8) void;
pub fn wasmLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();

    var str = std.ArrayList(u8).init(std.heap.wasm_allocator);
    var writer = str.writer().any();

    writer.print("level: {s};scope: {s};\r\n", .{ level_txt, @tagName(scope) }) catch unreachable;
    writer.print(format, args) catch unreachable;
    const owned = str.toOwnedSliceSentinel(0) catch unreachable;

    externalLog(owned.ptr);
    std.heap.wasm_allocator.free(owned);
}
var gpa = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
    .verbose_log = true,
}){};

const wasm_allocator = blk: {
    if (is_debug or !is_wasm) {
        break :blk gpa.allocator();
    } else {
        break :blk std.heap.wasm_allocator;
    }
};

pub fn main() void {}

pub inline fn wasm_try(T: type, triable: anytype) T {
    return triable catch |e| {
        @panic(@errorName(e));
    };
}

export fn allocBuffer(size: usize) [*]u8 {
    logger.info("allocBuffer({d})", .{size});
    return wasm_try([]u8, wasm_allocator.alloc(u8, size)).ptr;
}
export fn allocNullTerminatedBuffer(size: usize) [*:0]u8 {
    logger.info("allocNullTerminatedBuffer({d})", .{size});
    const ptr = wasm_try([*:0]u8, wasm_allocator.allocSentinel(u8, size, 0));
    return ptr;
}
export fn freeNullTerminatedBuffer(ptr: [*:0]u8) void {
    logger.info("freeNullTerminatedBuffer({d})", .{std.mem.len(ptr)});
    const slice = ptr[0 .. std.mem.len(ptr) + 1];
    wasm_allocator.free(slice);
}
export fn freeBuffer(ptr: [*]u8, size: usize) void {
    logger.info("freeBuffer({d})", .{size});
    wasm_allocator.free(ptr[0..size]);
}

export fn Tree_init() *Tree {
    const ptr = wasm_try(*Tree, wasm_allocator.create(Tree));
    ptr.* = wasm_try(Tree, Tree.init(wasm_allocator));

    logger.info("Tree_init():{*}", .{ptr});
    return ptr;
}
export fn Tree_deinit(tree: *Tree) void {
    logger.info("Tree_deinit({*})", .{tree});
    tree.deinit();
    wasm_allocator.destroy(tree);
}

fn trim(slice: []const u8) []const u8 {
    var begin: usize = 0;
    var end: usize = slice.len;
    while (begin < end and std.ascii.isWhitespace(slice[begin])) : (begin += 1) {}
    while (end > begin and std.ascii.isWhitespace(slice[end - 1])) : (end -= 1) {}
    return slice[begin..end];
}
export fn Tree_createNode(tree: *Tree, styles: [*:0]u8) u32 {
    logger.info("Tree_createNode({*}, \"{s}\")", .{ tree, styles });
    defer freeNullTerminatedBuffer(styles);
    const style_slice = styles[0..std.mem.len(styles)];
    const node = wasm_try(Tree.Node.NodeId, tree.createNode());
    wasm_try(void, parsers.parseStyleString(tree, node, style_slice));

    return @intCast(node);
}
export fn Tree_createTextNode(tree: *Tree, text: [*:0]u8) u32 {
    logger.info("Tree_createTextNode({*}, {s})", .{ tree, text });
    defer freeNullTerminatedBuffer(text);
    const text_slice = text[0..std.mem.len(text)];
    return @intCast(wasm_try(Tree.Node.NodeId, tree.createTextNode(text_slice)));
}
var ctx: void = {};
export fn Tree_enableInputManager(tree: *Tree) void {
    logger.info("Tree_enableInputManager({*})", .{tree});
    wasm_try(void, tree.enableInputManager());
    wasm_try(void, tree.input_manager.?.subscribe(.{
        .context = &ctx,
        .emitFn = emitEventFn,
    }));
}
export fn Tree_disableInputManager(tree: *Tree) void {
    logger.info("Tree_disableInputManager({*})", .{tree});
    tree.disableInputManager();
}
const external = if (!builtin.is_test) struct {
    extern fn emitEvent(data: [*]const u32) void;
} else struct {
    pub fn emitEvent(_: [*]const u32) void {}
};
pub fn emitEventFn(_: *anyopaque, event: InputManager.Event) void {
    var event_buffer: [8]u32 = undefined;
    switch (event.data) {
        .key => |key| {
            const action: u32 = @intCast(@intFromEnum(key.action));
            event_buffer[0] = 1;
            event_buffer[1] = 0; // reserve for future event id
            event_buffer[2] = key.codepoint;
            event_buffer[3] = key.base_codepoint;
            event_buffer[4] = action;
            event_buffer[5] = event.modifiers;
            external.emitEvent((&event_buffer).ptr);
        },
        .paste_chunk => |paste| {
            const kind: u32 = @intCast(@intFromEnum(paste.kind));
            event_buffer[0] = 2;
            event_buffer[1] = 0; // reserve for future event id
            event_buffer[2] = kind;
            event_buffer[3] = @intCast(@intFromPtr(paste.chunk.ptr));
            event_buffer[4] = @intCast(paste.chunk.len);
            external.emitEvent((&event_buffer).ptr);
        },
        .mouse => |mouse| {
            // const action: u32 = @intCast(@intFromEnum(mouse.));
            switch (mouse) {
                .extended => |extended| {
                    event_buffer[0] = 5;
                    event_buffer[1] = 0; // reserve for future event id
                    event_buffer[2] = @intFromEnum(extended.button);
                    event_buffer[3] = @intFromEnum(extended.action);
                    event_buffer[4] = extended.x;
                    event_buffer[5] = extended.y;
                    external.emitEvent((&event_buffer).ptr);
                },
                else => {},
            }
        },
        else => {},
        // .paste =>|paste| {
        //     const data = [_]u32{ 2, event.paste.kind, event.paste.body_position, event.paste.body_length, event.paste.position, event.paste.length };
        //     emitEvent(&data);
        // },
    }

    // ctx.consumed += handleRawBuffer(ctx, ctx.buffer.items[ctx.consumed..]);
}

export fn Tree_consumeEvents(tree: *Tree, array_buffer: *std.ArrayList(u8), force: bool) u32 {
    var manager = tree.input_manager orelse std.debug.panic("Input manager not enabled", .{});
    const original_mode = manager.mode;
    if (force) {
        manager.setMode(.force);
    }
    const consumed = handleRawBuffer(&manager, array_buffer.items, 0);
    if (force) {
        manager.setMode(original_mode);
    }
    return @intCast(consumed);
}
export fn Tree_getNodeKind(tree: *Tree, node: u32) u32 {
    logger.info("Tree_getNodeKind({*}, {d})", .{ tree, node });
    return @intFromEnum(tree.getNodeKind(node));
}
export fn Tree_destroyNode(tree: *Tree, node: u32) void {
    logger.info("Tree_destroyNode({*}, {d})", .{ tree, node });
    wasm_try(void, tree.destroyNode(node));
}
export fn Tree_destroyNodeRecursive(tree: *Tree, node: u32) void {
    logger.info("Tree_destroyNodeRecursive({*}, {d})", .{ tree, node });
    wasm_try(void, tree.destroyNodeRecursive(node));
}
export fn Tree_appendChild(tree: *Tree, parent: u32, child: u32) u32 {
    logger.info("Tree_appendChild({*}, {d}, {d})", .{ tree, parent, child });
    return @intCast(wasm_try(Tree.Node.NodeId, tree.appendChild(parent, child)));
}
export fn Tree_insertBefore(tree: *Tree, child: u32, before: u32) u32 {
    logger.info("Tree_insertBefore({*}, {d}, {d})", .{ tree, child, before });
    return @intCast(wasm_try(Tree.Node.NodeId, tree.insertBefore(child, before)));
}
export fn Tree_removeChildren(tree: *Tree, parent: u32) void {
    logger.info("Tree_removeChildren({*}, {d})", .{ tree, parent });
    tree.removeChildren(parent);
}

export fn Tree_removeChild(tree: *Tree, parent: u32, child: u32) void {
    logger.info("Tree_removeChild({*}, {d}, {d})", .{ tree, parent, child });
    wasm_try(void, tree.removeChild(parent, child));
}
export fn Tree_getChildrenCount(tree: *Tree, parent: u32) u32 {
    logger.info("Tree_getChildrenCount({*}, {d})", .{ tree, parent });
    return @intCast(tree.getChildren(parent).items.len);
    // return 0;
}
export fn Tree_getChildren(tree: *Tree, node_id: u32) [*]u32 {
    logger.info("Tree_getChildren({*}, {d})", .{ tree, node_id });

    return @ptrCast(tree.getChildren(node_id).items.ptr);
}
export fn Tree_getNodeParent(tree: *Tree, node: u32) i32 {
    logger.info("Tree_getNodeParent({*}, {d})", .{ tree, node });
    if (tree.getNode(node).parent) |parent| {
        return @intCast(parent);
    }
    return -1;
}
export fn Tree_appendChildAtIndex(tree: *Tree, parent: u32, child: u32, index: u32) u32 {
    logger.info("Tree_appendChildAtIndex({*}, {d}, {d}, {d})", .{ tree, parent, child, index });
    return @intCast(wasm_try(Tree.Node.NodeId, tree.appendChildAtIndex(parent, child, index)));
}
export fn Tree_getNodeCursorStyle(tree: *Tree, node: u32) u32 {
    logger.info("Tree_getNodeCursorStyle({*}, {d})", .{ tree, node });
    const style = tree.getComputedStyle(node);
    return @intFromEnum(style.cursor);
}
export fn Tree_setStyle(tree: *Tree, node: u32, string: [*:0]u8) void {
    logger.info("Tree_setStyle({*}, {d}, \"{s}\")", .{ tree, node, string });
    defer freeNullTerminatedBuffer(string);
    tree.getNode(node).styles = .{};
    const style_slice = string[0..std.mem.len(string)];
    wasm_try(void, parsers.parseStyleString(tree, node, style_slice));
}
export fn Tree_setStyleProperty(tree: *Tree, node: u32, key: [*:0]u8, value: [*:0]u8) void {
    logger.info("Tree_setStyleProperty({*}, {d}, \"{s}\", \"{s}\")", .{ tree, node, key, value });
    defer freeNullTerminatedBuffer(key);
    defer freeNullTerminatedBuffer(value);
    // tree.computed_style_cache.invalidateNode(node);
    parsers.parseStyleProperty(
        tree,
        node,
        key[0..std.mem.len(key)],
        value[0..std.mem.len(value)],
    );
}
export fn Tree_doesNodeExist(tree: *Tree, node: u32) bool {
    return tree.node_map.contains(node);
}

export fn Tree_getNodeContains(tree: *Tree, root: u32, node: u32) bool {
    return tree.getNodeContains(root, node);
}

export fn Tree_getNodeScrollTop(tree: *Tree, node_id: u32) f32 {
    logger.info("Tree_getNodeScrollTop({*}, {d})", .{ tree, node_id });
    return tree.getNode(node_id).scroll_offset.y;
}
export fn Tree_getNodeScrollLeft(tree: *Tree, node_id: u32) f32 {
    logger.info("Tree_getNodeScrollLeft({*}, {d})", .{ tree, node_id });
    return tree.getNode(node_id).scroll_offset.x;
}
export fn Tree_setNodeScrollTop(tree: *Tree, node_id: u32, y: f32) void {
    logger.info("Tree_setNodeScrollTop({*}, {d}, {d})", .{ tree, node_id, y });
    tree.getNode(node_id).scroll_offset.y = y;
}
export fn Tree_setNodeScrollLeft(tree: *Tree, node_id: u32, x: f32) void {
    logger.info("Tree_setNodeScrollLeft({*}, {d}, {d})", .{ tree, node_id, x });
    tree.getNode(node_id).scroll_offset.x = x;
}
// export fn Tree_getNodeScrollYMax(tree: *Tree, node_id: u32) f32 {
//     const node = tree.getNode(node_id);
//     const parent_layout = tree.getLayout(node.parent orelse return 0);
//     const inner_size = parent_layout.size.sub(parent_layout.border.sumAxes()).sub(parent_layout.padding.sumAxes());
//     return tree.getLayout(node_id).content_size.y - inner_size.y;
// }

export fn Tree_getNodeScrollHeight(tree: *Tree, node_id: u32) f32 {
    logger.info("Tree_getNodeScrollHeight({*}, {d})", .{ tree, node_id });
    return tree.getLayout(node_id).content_size.y;
}
export fn Tree_getNodeScrollWidth(tree: *Tree, node_id: u32) f32 {
    logger.info("Tree_getNodeScrollWidth({*}, {d})", .{ tree, node_id });
    return tree.getLayout(node_id).content_size.x;
}

export fn Tree_getNodeClientHeight(tree: *Tree, node_id: u32) f32 {
    logger.info("Tree_getNodeClientHeight({*}, {d})", .{ tree, node_id });
    const layout = tree.getLayout(node_id);
    return layout.size.y - layout.border.sumAxes().y;
}

export fn Tree_getNodeClientWidth(tree: *Tree, node_id: u32) f32 {
    logger.info("Tree_getNodeClientWidth({*}, {d})", .{ tree, node_id });
    const layout = tree.getLayout(node_id);
    return layout.size.x - layout.border.sumAxes().x;
}

const tree_dump_logger = std.log.scoped(.tree_dump);
export fn Tree_dump(tree: *Tree) void {
    var array_list = std.ArrayList(u8).init(wasm_allocator);
    defer array_list.deinit();
    wasm_try(void, tree.print(array_list.writer().any()));
    tree_dump_logger.info("{s}", .{array_list.items});
}
export fn Tree_setText(tree: *Tree, node: u32, text: [*:0]u8) void {
    logger.info("Tree_setText({*}, {d}, \"{s}\")", .{ tree, node, text });
    defer freeNullTerminatedBuffer(text);
    const text_slice = text[0..std.mem.len(text)];
    wasm_try(void, tree.setText(node, text_slice));
}
export fn Tree_computeLayout(tree: *Tree, width: [*:0]u8, height: [*:0]u8) void {
    logger.info("Tree_computeLayout({*}, \"{s}\", \"{s}\")", .{ tree, width, height });
    defer freeNullTerminatedBuffer(width);
    defer freeNullTerminatedBuffer(height);
    const width_slice = std.mem.trim(u8, width[0..std.mem.len(width)], " \n\t\r");
    const height_slice = std.mem.trim(u8, height[0..std.mem.len(height)], " \n\t\r");
    wasm_try(void, tree.computeLayout(wasm_allocator, .{
        .x = width: {
            if (std.mem.eql(u8, width_slice, "min-content")) {
                break :width .min_content;
            } else if (std.mem.eql(u8, width_slice, "max-content")) {
                break :width .max_content;
            }
            const definite = wasm_try(f32, std.fmt.parseFloat(f32, width_slice));
            break :width .{ .definite = definite };
        },
        .y = height: {
            if (std.mem.eql(u8, height_slice, "min-content")) {
                break :height .min_content;
            } else if (std.mem.eql(u8, height_slice, "max-content")) {
                break :height .max_content;
            }
            const definite = wasm_try(f32, std.fmt.parseFloat(f32, height_slice));
            break :height .{ .definite = definite };
        },
    }));
}
export fn Renderer_renderToStdout(renderer: *Renderer, tree: *Tree, clear_screen: bool) void {
    logger.info("Renderer_renderToStdout({*}, {*}, {any})", .{ renderer, tree, clear_screen });
    wasm_try(void, renderer.render(wasm_allocator, tree, std.io.getStdOut().writer().any(), clear_screen));
}
export fn Renderer_init() *Renderer {
    logger.info("Renderer_init()", .{});
    const renderer = wasm_try(*Renderer, wasm_allocator.create(Renderer));
    renderer.* = wasm_try(Renderer, Renderer.init(wasm_allocator));
    return renderer;
}
export fn Renderer_deinit(renderer: *Renderer) void {
    logger.info("Renderer_deinit({*})", .{renderer});
    renderer.deinit();
    wasm_allocator.destroy(renderer);
}
export fn Renderer_getNodeAt(renderer: *Renderer, x: f32, y: f32) u32 {
    logger.info("Renderer_getNodeAt({*}, {d}, {d})", .{ renderer, x, y });
    return @intCast(renderer.getNodeAt(.{
        .x = x,
        .y = y,
    }) orelse std.math.maxInt(u32));
}
export const EventBuffer = [_]u8{1} ** 128;

fn readBufferWithLength(memory: [*]u8) []const u8 {
    const len = std.mem.readInt(u32, memory[0..4], .little);
    const slice = memory[4 .. len + 4];
    return slice;
}
fn freeBufferWithLength(memory: [*]u8) void {
    const len = std.mem.readInt(u32, memory[0..4], .little);
    freeBuffer(memory, len + 4);
}
export fn TermInfo_initFromMemory(memory: [*]u8) *TermInfo {
    logger.info("TermInfo_initFromMemory({*})", .{memory});
    const slice = readBufferWithLength(memory);
    defer freeBufferWithLength(memory);
    const term_info = wasm_try(*TermInfo, wasm_allocator.create(TermInfo));
    term_info.* = wasm_try(TermInfo, TermInfo.initFromMemory(wasm_allocator, slice));
    return term_info;
}
export fn TermInfo_deinit(term_info: *TermInfo) void {
    logger.info("TermInfo_deinit({*})", .{term_info});
    term_info.deinit();
    wasm_allocator.destroy(term_info);
}

// extern fn emitData(data: [*]u8, len: usize) void;

export fn ArrayList_init() *std.ArrayList(u8) {
    const ptr = wasm_try(*std.ArrayList(u8), wasm_allocator.create(std.ArrayList(u8)));
    ptr.* = std.ArrayList(u8).init(wasm_allocator);
    return ptr;
}
export fn ArrayList_deinit(list: *std.ArrayList(u8)) void {
    list.deinit();
    wasm_allocator.destroy(list);
}

export fn ArrayList_appendUnusedSlice(list: *std.ArrayList(u8), capacity: usize) [*]u8 {
    wasm_try(void, list.ensureUnusedCapacity(capacity));
    list.items.len += capacity;
    const unused_capacity_pointer = list.items[list.items.len - capacity ..];
    return unused_capacity_pointer.ptr;
}
export fn ArrayList_getLength(list: *std.ArrayList(u8)) usize {
    return list.items.len;
}
export fn ArrayList_setLength(list: *std.ArrayList(u8), length: usize) void {
    list.items.len = length;
}
export fn memcopy(dest: [*]u8, src: [*]u8, n: usize) void {
    std.mem.copyForwards(u8, dest[0..n], src[0..n]);
}
export fn ArrayList_getPointer(list: *std.ArrayList(u8)) [*]u8 {
    return list.items.ptr;
}
export fn ArrayList_clearRetainingCapacity(list: *std.ArrayList(u8)) void {
    list.clearRetainingCapacity();
}
export fn ArrayList_dump(list: *std.ArrayList(u8)) void {
    std.debug.print("ArrayList: {any}\n", .{list.items});
}

const handleRawBuffer = @import("cmd/input.zig").handleRawBuffer;
// const WasmInputManager = InputManager.InputManager(*WasmManager, WasmManager.emitEventFn, WasmManager.setModeFn);
// const WasmManager = struct {
//     buffer: std.ArrayList(u8),
//     consumed: usize = 0,
//     mode: InputManager.Mode = .normal,
//     pub fn init(allocator: std.mem.Allocator) @This() {
//         return .{
//             .buffer = std.ArrayList(u8).init(allocator),
//         };
//     }
//     pub fn deinit(self: *@This()) void {
//         self.buffer.deinit();
//     }

//     pub inline fn manager(self: *@This()) WasmInputManager {
//         return .{
//             .context = self,
//             .mode = self.mode,
//         };
//     }

//     // Events encoding
//     // key event
//     // action: 0 = press, 1 = release, 2 = repeat
//     // [1, eventId, codepoint: u32, base_codepoint: u32, action: u32, modifiers: u32, position: u32, length: u32]
//     // paste
//     // kind: 0 = start, end = 1, chunk = 2, all: 3
//     // [2, eventId, kind: u32, body_position: u32, body_length: u32, position: u32, length: u32]
//     // focus
//     // 0 = unfocused, 1 = focused
//     // [3, eventId, focused: u32]
//     // cursor report normal mode
//     // left_press = 0, middle_press = 1, right_press = 2, release = 3, wheel_forward = 4, wheel_back = 5, wheel_tilt_left = 6, wheel_tilt_right = 7
//     // [4, eventId,  x: u32, y: u32, action: u32]
//     // mouse report extended mode
//     // button: 0 = left, 1 = middle, 2 = right, 3 = wheel, 4 = button8, 5 = button9, 6 = button10, 7 = button11, 8 = none
//     // action: 0 = press, 1 = release, 2 = motion, 3 = wheel_up, 4 = wheel_down, 5 = wheel_left, 6 = wheel_right
//     // [5, eventId, button: u32, action: u32, x: u32, y: u32]

//     const external = if (!builtin.is_test) struct {
//         extern fn emitEvent(data: [*]const u32) void;
//     } else struct {
//         pub fn emitEvent(_: [*]const u32) void {}
//     };
//     var event_buffer: [8]u32 = undefined;
//     pub fn setModeFn(self: *WasmManager, mode: InputManager.Mode) void {
//         self.mode = mode;
//     }

//     pub fn emitEventFn(ctx: *WasmManager, event: InputManager.Event) void {
//         _ = ctx; // autofix
//         switch (event.data) {
//             .key => |key| {
//                 const action: u32 = @intCast(@intFromEnum(key.action));
//                 event_buffer[0] = 1;
//                 event_buffer[1] = 0; // reserve for future event id
//                 event_buffer[2] = key.codepoint;
//                 event_buffer[3] = key.base_codepoint;
//                 event_buffer[4] = action;
//                 event_buffer[5] = event.modifiers;
//                 external.emitEvent((&event_buffer).ptr);
//             },
//             .paste_chunk => |paste| {
//                 const kind: u32 = @intCast(@intFromEnum(paste.kind));
//                 event_buffer[0] = 2;
//                 event_buffer[1] = 0; // reserve for future event id
//                 event_buffer[2] = kind;
//                 event_buffer[3] = @intCast(@intFromPtr(paste.chunk.ptr));
//                 event_buffer[4] = @intCast(paste.chunk.len);
//                 external.emitEvent((&event_buffer).ptr);
//             },
//             else => {},
//             // .paste =>|paste| {
//             //     const data = [_]u32{ 2, event.paste.kind, event.paste.body_position, event.paste.body_length, event.paste.position, event.paste.length };
//             //     emitEvent(&data);
//             // },
//         }

//         // ctx.consumed += handleRawBuffer(ctx, ctx.buffer.items[ctx.consumed..]);
//     }
// };
// export fn InputManager_init() *WasmManager {
//     const input_manager = wasm_try(*WasmManager, wasm_allocator.create(WasmManager));
//     input_manager.* = WasmManager.init(wasm_allocator);
//     return input_manager;
// }

// export fn InputManager_deinit(input_manager: *WasmManager) void {
//     input_manager.deinit();
//     wasm_allocator.destroy(input_manager);
// }

// export fn InputManager_consumeEvents(input_manager: *WasmManager, array_buffer: *std.ArrayList(u8), force: bool) u32 {
//     var manager = input_manager.manager().any();
//     const original_mode = manager._mode;
//     if (force) {
//         manager.setMode(.force);
//     }
//     const consumed = handleRawBuffer(&manager, array_buffer.items, 0);
//     if (force) {
//         manager.setMode(original_mode);
//     }
//     return @intCast(consumed);
// }

export fn detectLeaks() bool {
    if (builtin.mode == .Debug) {
        const leaks = gpa.detectLeaks();
        return leaks;
    }
    return false;
}

fn allocTestString(str: []const u8) [*:0]u8 {
    const ptr: [*:0]u8 = allocNullTerminatedBuffer(str.len);
    std.mem.copyForwards(u8, ptr[0..str.len], str);
    return ptr;
}
test "wasm" {
    const tree = Tree_init();
    defer Tree_deinit(tree);
    const style_ptr = allocTestString("background-color: red;height: 10;width: 50;");

    const node = Tree_createNode(tree, style_ptr);
    const child = Tree_createNode(tree, allocTestString(
        \\background-color: blue;
        \\border: rounded;
        \\margin: 1;
        \\height: 9;
        \\width: 4;
    ));
    Tree_appendChild(tree, node, child);
    Tree_computeLayout(tree, allocTestString("50"), allocTestString("10"));
    const renderer = Renderer_init();
    defer Renderer_deinit(renderer);
    Renderer_renderToStdout(renderer, tree, false);
    Tree_dump(tree);
}

test "should_set_style" {
    defer _ = gpa.detectLeaks();
    {
        const tree = Tree_init();
        defer Tree_deinit(tree);
        const node = Tree_createNode(tree, allocTestString(""));
        const style = allocTestString("background-color: blue; width: 100px;");
        Tree_setStyle(tree, node, style);

        // // We can't directly check the style value, but we can compute layout and check dimensions
        const width = allocTestString("200");
        // defer freeNullTerminatedBuffer(width);
        const height = allocTestString("200");
        // defer freeNullTerminatedBuffer(height);
        Tree_computeLayout(tree, width, height);
        const width_result = Tree_getNodeClientWidth(tree, node);
        try std.testing.expectEqual(width_result, 100);
    }

    {
        const tree = Tree_init();
        defer Tree_deinit(tree);
        const node = Tree_createNode(tree, allocTestString(""));
        Tree_setStyle(tree, node, allocTestString("background-color: blue; width: 100px;"));

        // We can't directly check the style value, but we can compute layout and check dimensions
        Tree_computeLayout(tree, allocTestString("200"), allocTestString("200"));
        const width = Tree_getNodeClientWidth(tree, node);
        try std.testing.expectEqual(width, 100);
        //   expect(Tree_getNodeClientWidth(tree, node)).toBe(100);
    }
}
const Cursor = @import("styles/cursor.zig").Cursor;

test "leak" {
    defer _ = gpa.detectLeaks();
    const tree = Tree_init();
    defer Tree_deinit(tree);
    const node = Tree_createTextNode(tree, allocTestString("hello"));
    inline for (std.meta.fields(Cursor)) |field| {
        Tree_setStyle(tree, node, allocTestString("background-color: blue;cursor: " ++ field.name ++ ";"));
        Tree_computeLayout(tree, allocTestString("200"), allocTestString("200"));
    }
}

test {
    _ = @import("./layout/tree/Range.zig");
    _ = @import("./uni/GraphemeBreak.zig");
}
