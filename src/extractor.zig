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

        try flatmapped_array.appendSlice("The giant magnetoimpedance (GMI) effect consists of the huge change of both real and imaginary parts of the impedance upon the application of static magnetic field. The relative change of impedance can reach ratios up to around 700%, with extremely large sensitivities in the very low field region. The magnetoimpedance phenomenon is observed in soft magnetic metals. Apart from the applied DC field, the main parameter determining GMI is the frequency of the driving current (which generates the circular AC driving magnetic field). In addition to fundamental aspects related to micromagnetics and to magnetization dynamics, the main interest of GMI effect lies in the large number of possibilities that it offers to technical researchers for employing this phenomenon as sensing principle in novel sensor devices. Under particular suitable conditions (ultrasoft magnetic character, adequate magnetic anisotropy, and adequate geometry), the GMI material undergoes modifications in its impedance in the presence of external agents such as static magnetic field and mechanical stress. Consequently, this variation of impedance is used as the measurement principle to sense the correlated changes in magnetic field strength, stress, or torsion. The chapter describes various types of sensors based on GMI, such as magnetic field sensors (wire and thin film technologies); current, position and rotation sensors (applications that derive from field sensing); stress sensors; and microwave applications, along with the particular characteristics necessary for the materials to be employed in GMI applications.");
        // for (texts_array.items) |text| {
        //     for (text) |c| {
        //         try flatmapped_array.append(c);
        //     }
        //     try flatmapped_array.append(' ');
        // }

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