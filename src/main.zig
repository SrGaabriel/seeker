const std = @import("std");
const rem = @import("rem");
const extractor = @import("extractor.zig");
const lexing = @import("lexer.zig");
const sorting = @import("sorting.zig");

const PAGE_TOKEN_LIMIT = 150;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = try readFile(allocator, "resources/books/pg74974-images.html");
    defer allocator.free(content);
    const utf21_list = try convertContentToUtf21(allocator, content);
    defer allocator.free(utf21_list);

    var dom = rem.Dom{ .allocator = allocator };
    defer dom.deinit();

    var parser = try rem.Parser.init(&dom, utf21_list, allocator, .report, false);
    defer parser.deinit();

    try parser.run();

    const text = try extractor.extract_text(parser.getDocument());
    defer text.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var lexer = lexing.Lexer.init(text.items);
    var tokens = try lexer.tokenize(arena_allocator);
    defer tokens.deinit();

    const term_frequency = try sorting.getFrequency([]u8, arena_allocator, &tokens, PAGE_TOKEN_LIMIT);
    for (term_frequency) |frequency| {
        std.debug.print("{s}: {d}\n", .{ frequency.token, frequency.mentions });
    }
}

pub fn readFile(allocator: std.mem.Allocator, file_path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);
    return buffer;
}

pub fn convertContentToUtf21(allocator: std.mem.Allocator, content: []const u8) ![]u21 {
    var utf21_list = std.ArrayList(u21).init(allocator);
    var utf8_view = std.unicode.Utf8View.init(content) catch {
        return error.InvalidUtf8;
    };
    var utf8_iterator = utf8_view.iterator();
    while (utf8_iterator.nextCodepoint()) |codepoint| {
        try utf21_list.append(codepoint);
    }
    return utf21_list.toOwnedSlice();
}
