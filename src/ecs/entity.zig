const std = @import("std");

pub const Entity = packed struct {
    index: u24,
    gen: u8,

    pub const invalid = @This(){
        .index = std.math.maxInt(u24),
        .gen = std.math.maxInt(u8),
    };

    pub fn eql(self: @This(), other: @This()) bool {
        return (self.index == other.index and self.gen == other.gen);
    }
};
