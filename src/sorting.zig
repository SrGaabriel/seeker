const std = @import("std");
const util = @import("util.zig");

pub const Frequency = struct { token: []u8, mentions: usize };

pub fn getFrequency(
    comptime T: type,
    allocator: std.mem.Allocator,
    list: *std.ArrayList(T),
    limit: usize
) ![]Frequency {
    // Create frequency map
    var frequency_map = std.ArrayHashMap(T, usize, ArrayContext, true).init(allocator);
    defer frequency_map.deinit();

    // Count frequencies
    for (list.items) |item| {
        const entry = try frequency_map.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    // Create array of key-value pairs for sorting
    var pairs = try allocator.alloc(Frequency, frequency_map.count());
    errdefer allocator.free(pairs);

    // Fill the array
    var it = frequency_map.iterator();
    var i: usize = 0;
    while (it.next()) |entry| : (i += 1) {
        pairs[i] = .{
            .token = entry.key_ptr.*,
            .mentions = entry.value_ptr.*,
        };
    }

    std.sort.pdq(Frequency, pairs, {}, SortingStrategy.GreaterThan);

    return pairs[0..limit];
}

const ArrayContext = struct {
    pub fn hash(_: ArrayContext, key: []u8) u32 {
        var h = std.hash.Fnv1a_32.init();
        h.update(key);
        return h.final();
    }

    pub fn eql(_: ArrayContext, left: []u8, right: []u8, _: usize) bool {
        return std.mem.eql(u8, left, right);
    }
};

const ImmutableArrayContext = struct {
    pub fn hash(_: ImmutableArrayContext, key: []const u8) u32 {
        var h = std.hash.Fnv1a_32.init();
        h.update(key);
        return h.final();
    }

    pub fn eql(_: ImmutableArrayContext, left: []const u8, right: []const u8, _: usize) bool {
        return std.mem.eql(u8, left, right);
    }
};

pub const SortingStrategy = struct {
    pub fn lessThan(_: void, a: Frequency, b: Frequency) bool {
        return a.mentions < b.mentions;
    }
    pub fn GreaterThan(_: void, a: Frequency, b: Frequency) bool {
        return a.mentions > b.mentions;
    }
};

pub const PageDictionary: type =
    std.ArrayHashMap([]const u8,[]Frequency, ImmutableArrayContext, true);