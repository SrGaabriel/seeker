const std = @import("std");

pub fn toUpperCase(input: *[]u8) ![]u8 {
    var i: usize = 0;
    for (input) |ch| {
        if (ch >= 'a' and ch <= 'z') {
            input[i] = ch - 32;
        } else {
            input[i] = ch;
        }
        i += 1;
    }
    return input;
}