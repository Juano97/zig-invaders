const std = @import("std");
const Entity = @import("entity.zig").Entity;
const SparseSet = @import("storage.zig").SparseSet;

fn typeId(comptime T: type) usize {
    _ = T;
    const S = struct {
        var id: u8 = 0;
    };
    return @intFromPtr(&S.id);
}

pub const World = struct {
    sets: std.AutoHashMap(usize, *anyopaque),
    gens: []u8,
    free_slots: std.ArrayList(u24),
    count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !@This() {
        const gens = try allocator.alloc(u8, capacity);
        errdefer allocator.free(gens);
        @memset(gens, 0);

        const sets = std.AutoHashMap(usize, *anyopaque).init(allocator);
        const free_slots = std.ArrayList(u24).init(allocator);

        return .{
            .sets = sets,
            .gens = gens,
            .free_slots = free_slots,
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.gens);
        self.sets.deinit();

        self.free_slots.deinit(); // TODO clean sparse sets
    }

    pub fn registerComponent(self: *@This(), comptime T: type, capacity: usize) !void {
        const set = try self.allocator.create(SparseSet(T));
        errdefer self.allocator.destroy(set);
        set.* = try SparseSet(T).init(self.allocator, capacity);
        try self.sets.put(typeId(T), @ptrCast(set));
    }
};
