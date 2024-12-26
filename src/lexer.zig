const std = @import("std");

pub const Lexer = struct {
    text: []u8,
    cursor: usize,

    pub fn init(text: []u8) Lexer {
        return Lexer { .text = text, .cursor = 0 };
    }

    pub fn tokenize(lexer: *Lexer, allocator: std.mem.Allocator) !std.ArrayList([]u8) {
        var tokens = std.ArrayList([]u8).init(allocator);

        while (lexer.cursor < lexer.text.len) {
            const c = lexer.text[lexer.cursor];

            switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9' => {
                    const token = try lexer.take_while(allocator, is_char_alphanumeric);
                    try tokens.append(token.items);
                },
                ' ', '\n', '\t' => {},
                else => {
                    // var array = std.ArrayList(u8).init(allocator);
                    // try array.append(c);
                    // try tokens.append(array.items);
                },
            }
            lexer.cursor += 1;
        }

        return tokens;
    }

    fn take_while(lexer: *Lexer, allocator: std.mem.Allocator, f: fn(u8) bool) !std.ArrayList(u8) {
        var elements = std.ArrayList(u8).init(allocator);

        while (lexer.cursor < lexer.text.len) {
            const c = lexer.text[lexer.cursor];
            if (!f(c)) {
                break;
            }
            try elements.append(c);
            lexer.cursor += 1;
        }

        return elements;
    }

    fn is_char_alphanumeric(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9');
    }
};
