const std = @import("std");
const zig_invaders = @import("zig_invaders");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try zig_invaders.bufferedPrint();
}
