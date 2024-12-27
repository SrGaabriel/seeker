const std = @import("std");
const rem = @import("rem");
const extractor = @import("extractor.zig");
const lexing = @import("lexer.zig");
const sorting = @import("sorting.zig");

const FOLDER = "resources/books/";
const PAGE_TOKEN_LIMIT = 150;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var dictionary = try readPagesInFolder(arena_allocator, FOLDER);
    defer dictionary.deinit();

    std.debug.print("The dictionary has been created with {d} entries.\n", .{dictionary.count()});
}

const ThreadContext = struct {
    dictionary: *sorting.PageDictionary,
    parent_allocator: std.mem.Allocator,
    file_path: []const u8,
    mutex: *std.Thread.Mutex,
};

pub fn readPagesInFolder(allocator: std.mem.Allocator, folder: []const u8) !sorting.PageDictionary {
    var dir = try std.fs.cwd().openDir(folder, .{ .iterate = true });
    defer dir.close();

    var dictionary = sorting.PageDictionary.init(allocator);
    var mutex = std.Thread.Mutex{};

    var threads = std.ArrayList(std.Thread).init(allocator);
    defer threads.deinit();

    var contexts = std.ArrayList(ThreadContext).init(allocator);
    defer contexts.deinit();

    var iterator = dir.iterate();
    var file_count: usize = 0;
    while (try iterator.next()) |_| {
        file_count += 1;
    }

    try threads.ensureTotalCapacity(file_count);
    try contexts.ensureTotalCapacity(file_count);

    iterator.reset();

    while (try iterator.next()) |entry| {
        const file_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ FOLDER, entry.name });
        
        try contexts.append(.{
            .dictionary = &dictionary,
            .parent_allocator = allocator,
            .file_path = file_path,
            .mutex = &mutex,
        });

        const thread = try std.Thread.spawn(
            .{},
            updateDictionary,
            .{&contexts.items[contexts.items.len - 1]}
        );
        try threads.append(thread);
    }

    for (threads.items) |thread| {
        thread.join();
    }

    for (contexts.items) |context| {
        allocator.free(context.file_path);
    }

    return dictionary;
}

pub fn updateDictionary(context: *const ThreadContext) void {
    var arena = std.heap.ArenaAllocator.init(context.parent_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const frequencies = indexFile(arena_allocator, context.file_path) catch |err| {
        std.debug.print("Error indexing file {s}: {any}\n", .{ context.file_path, err });
        return;
    };
    
    context.mutex.lock();
    defer context.mutex.unlock();
    
    _ = context.dictionary.put(context.file_path, frequencies) catch |err| {
        std.debug.print("Error updating dictionary for {s}: {any}\n", .{ context.file_path, err });
        return;
    };
    
    std.debug.print("The file {s} has been indexed.\n", .{context.file_path});
}

pub fn indexFile(allocator: std.mem.Allocator, file_path: []const u8) ![]sorting.Frequency {
    const content = try readFile(allocator, file_path);
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

    var lexer = lexing.Lexer.init(text.items);
    var tokens = try lexer.tokenize(allocator);
    defer tokens.deinit();

    const term_frequency = try sorting.getFrequency([]u8, allocator, &tokens, PAGE_TOKEN_LIMIT);
    return term_frequency;
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
