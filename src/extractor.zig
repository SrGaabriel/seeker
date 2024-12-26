const std = @import("std");
const rem = @import("rem");

const ExtractionError = error {
    NoElement,
};

pub fn extract_text(document: *rem.Dom.Document) !std.ArrayList(u8) {
    const element = document.element;

    if (element) |e| {
        std.debug.print("DEBUG: Root has {d} children\n", .{e.children.items.len});
        var texts_array = std.ArrayList([]u8).init(std.heap.page_allocator);
        defer texts_array.deinit();

        try extract_text_from_element(&texts_array, e);
        var flatmapped_array = std.ArrayList(u8).init(std.heap.page_allocator);

        for (texts_array.items) |text| {
            for (text) |c| {
                try flatmapped_array.append(c);
            }
            try flatmapped_array.append(' ');
        }

        return flatmapped_array;
    } else {
        return ExtractionError.NoElement;
    }
}

fn extract_text_from_element(texts: *std.ArrayList([]u8), element: *const rem.Dom.Element) !void {
    for (element.children.items) |child| {
        switch (child) {
            .element => |e| {
                switch (e.element_type) {
                    rem.Dom.ElementType.html_script,
                    rem.Dom.ElementType.html_style,
                    rem.Dom.ElementType.html_table => { continue; },
                    rem.Dom.ElementType.html_head => { continue; },
                    else => { try extract_text_from_element(texts, e); },
                }
            },
            .cdata => |t| {
                if (t.interface == rem.Dom.CharacterDataInterface.text) {
                    try texts.append(t.data.items);
                }
            },
        }
    }
}