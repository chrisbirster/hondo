const std = @import("std");
const scene_module = @import("../scene.zig");
const cell_grid = @import("cell_grid.zig");

pub const Direction = enum {
    column,
    row,
};

pub const LayoutStyle = struct {
    direction: Direction = .column,
    width: ?usize = null,
    height: ?usize = null,
    gap: usize = 0,
};

const Rect = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,
};

pub fn render(scene: *scene_module.Scene, grid: *cell_grid.CellGrid) !void {
    grid.clear();
    try renderNode(scene, 0, grid, .{
        .x = 0,
        .y = 0,
        .width = grid.width,
        .height = grid.height,
    });
}

fn renderNode(
    scene: *scene_module.Scene,
    node_id: scene_module.NodeId,
    grid: *cell_grid.CellGrid,
    bounds: Rect,
) !void {
    if (bounds.width == 0 or bounds.height == 0) return;
    const node = try scene.getNode(node_id);

    if (node.kind == .text) {
        if (node.text) |text| grid.paintUtf8(bounds.x, bounds.y, text, bounds.width);
        return;
    }

    const style = try styleForNode(scene, node_id, node.type_name);
    const available_width = @min(bounds.width, style.width orelse bounds.width);
    const available_height = @min(bounds.height, style.height orelse bounds.height);
    if (available_width == 0 or available_height == 0) return;

    var cursor_x = bounds.x;
    var cursor_y = bounds.y;
    for (node.children.items, 0..) |child_id, index| {
        const child = try scene.getNode(child_id);
        const child_style = try styleForNode(scene, child_id, child.type_name);

        switch (style.direction) {
            .column => {
                if (cursor_y >= bounds.y + available_height) break;
                const remaining_height = bounds.y + available_height - cursor_y;
                const default_height = if (child.kind == .text) naturalHeight(child) else remaining_height;
                const child_height = @min(child_style.height orelse default_height, remaining_height);
                const child_width = @min(child_style.width orelse available_width, available_width);
                try renderNode(scene, child_id, grid, .{
                    .x = bounds.x,
                    .y = cursor_y,
                    .width = child_width,
                    .height = child_height,
                });
                cursor_y += child_height;
                if (index + 1 < node.children.items.len) cursor_y +|= style.gap;
            },
            .row => {
                if (cursor_x >= bounds.x + available_width) break;
                const remaining_width = bounds.x + available_width - cursor_x;
                const default_width = if (child.kind == .text) naturalWidth(child) else remaining_width;
                const child_width = @min(child_style.width orelse default_width, remaining_width);
                const child_height = @min(child_style.height orelse available_height, available_height);
                try renderNode(scene, child_id, grid, .{
                    .x = cursor_x,
                    .y = bounds.y,
                    .width = child_width,
                    .height = child_height,
                });
                cursor_x += child_width;
                if (index + 1 < node.children.items.len) cursor_x +|= style.gap;
            },
        }
    }
}

fn styleForNode(scene: *scene_module.Scene, node_id: scene_module.NodeId, type_name: []const u8) !LayoutStyle {
    var style = LayoutStyle{};
    if (std.mem.eql(u8, type_name, "row")) style.direction = .row;
    if (std.mem.eql(u8, type_name, "column")) style.direction = .column;

    const json = (try scene.getPropertyJson(node_id, "style")) orelse return style;
    if (jsonStringValue(json, "direction")) |direction| {
        if (std.mem.eql(u8, direction, "row")) style.direction = .row;
        if (std.mem.eql(u8, direction, "column")) style.direction = .column;
    }
    style.width = jsonUnsignedValue(json, "width");
    style.height = jsonUnsignedValue(json, "height");
    style.gap = jsonUnsignedValue(json, "gap") orelse 0;
    return style;
}

fn naturalWidth(node: *const scene_module.Node) usize {
    if (node.kind == .text) return if (node.text) |text| utf8CodepointCount(text) else 0;
    return 1;
}

fn naturalHeight(node: *const scene_module.Node) usize {
    _ = node;
    return 1;
}

fn utf8CodepointCount(text: []const u8) usize {
    var count: usize = 0;
    var index: usize = 0;
    while (index < text.len) : (count += 1) {
        const len = std.unicode.utf8ByteSequenceLength(text[index]) catch 1;
        index += @min(len, text.len - index);
    }
    return count;
}

fn jsonUnsignedValue(json: []const u8, key: []const u8) ?usize {
    const value_start = jsonValueStart(json, key) orelse return null;
    var end = value_start;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == value_start) return null;
    return std.fmt.parseInt(usize, json[value_start..end], 10) catch null;
}

fn jsonStringValue(json: []const u8, key: []const u8) ?[]const u8 {
    const value_start = jsonValueStart(json, key) orelse return null;
    if (value_start >= json.len or json[value_start] != '"') return null;
    const start = value_start + 1;
    const relative_end = std.mem.indexOfScalar(u8, json[start..], '"') orelse return null;
    return json[start .. start + relative_end];
}

fn jsonValueStart(json: []const u8, key: []const u8) ?usize {
    var pattern_buffer: [128]u8 = undefined;
    if (key.len + 2 > pattern_buffer.len) return null;
    pattern_buffer[0] = '"';
    @memcpy(pattern_buffer[1 .. 1 + key.len], key);
    pattern_buffer[key.len + 1] = '"';
    const pattern = pattern_buffer[0 .. key.len + 2];

    const key_index = std.mem.indexOf(u8, json, pattern) orelse return null;
    const after_key = key_index + pattern.len;
    const colon_relative = std.mem.indexOfScalar(u8, json[after_key..], ':') orelse return null;
    var value_start = after_key + colon_relative + 1;
    while (value_start < json.len and std.ascii.isWhitespace(json[value_start])) : (value_start += 1) {}
    return value_start;
}

test "scene renderer lays out a row with gap and clips text" {
    var scene = try scene_module.Scene.init(std.testing.allocator);
    defer scene.deinit();

    try scene.createElement(1, "row");
    try scene.createText(2, "ABC");
    try scene.createText(3, "XYZ");
    try scene.setPropertyJson(1, "style", "{\"gap\":1,\"width\":6}");
    try scene.insertNode(0, 1, null);
    try scene.insertNode(1, 2, null);
    try scene.insertNode(1, 3, null);

    var grid = try cell_grid.CellGrid.init(std.testing.allocator, 6, 1);
    defer grid.deinit();
    try render(&scene, &grid);

    const row = try grid.rowUtf8(std.testing.allocator, 0);
    defer std.testing.allocator.free(row);
    try std.testing.expectEqualStrings("ABC XY", row);
}

test "scene renderer composes columns and honors explicit child width" {
    var scene = try scene_module.Scene.init(std.testing.allocator);
    defer scene.deinit();

    try scene.createElement(1, "column");
    try scene.createText(2, "first");
    try scene.createText(3, "second");
    try scene.setPropertyJson(2, "style", "{\"width\":3}");
    try scene.setPropertyJson(1, "style", "{\"gap\":1}");
    try scene.insertNode(0, 1, null);
    try scene.insertNode(1, 2, null);
    try scene.insertNode(1, 3, null);

    var grid = try cell_grid.CellGrid.init(std.testing.allocator, 6, 3);
    defer grid.deinit();
    try render(&scene, &grid);

    const first = try grid.rowUtf8(std.testing.allocator, 0);
    defer std.testing.allocator.free(first);
    const spacer = try grid.rowUtf8(std.testing.allocator, 1);
    defer std.testing.allocator.free(spacer);
    const second = try grid.rowUtf8(std.testing.allocator, 2);
    defer std.testing.allocator.free(second);

    try std.testing.expectEqualStrings("fir   ", first);
    try std.testing.expectEqualStrings("      ", spacer);
    try std.testing.expectEqualStrings("second", second);
}
