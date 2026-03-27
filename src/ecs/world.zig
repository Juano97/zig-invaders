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
    sets: std.AutoHashMap(usize, Entry),
    gens: []u8,
    free_slots: std.ArrayList(u24),
    count: u32,
    allocator: std.mem.Allocator,

    const Entry = struct {
        ptr: *anyopaque,
        deinit_fn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !@This() {
        const gens = try allocator.alloc(u8, capacity);
        errdefer allocator.free(gens);
        @memset(gens, 0);

        const sets = std.AutoHashMap(usize, Entry).init(allocator);
        const free_slots: std.ArrayList(u24) = .empty;

        return .{
            .sets = sets,
            .gens = gens,
            .free_slots = free_slots,
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        var it = self.sets.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit_fn(entry.value_ptr.ptr, self.allocator);
        }
        self.free_slots.deinit(self.allocator);
        self.allocator.free(self.gens);
        self.sets.deinit();
    }

    pub fn registerComponent(self: *@This(), comptime T: type, capacity: usize) !void {
        if (self.sets.contains(typeId(T))) return error.ComponentAlreadyRegistered;

        const set = try self.allocator.create(SparseSet(T));
        errdefer self.allocator.destroy(set);
        set.* = try SparseSet(T).init(self.allocator, capacity);

        const deinit_fn = struct {
            fn f(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                const s: *SparseSet(T) = @ptrCast(@alignCast(ptr));
                s.deinit();
                allocator.destroy(s);
            }
        }.f;

        try self.sets.put(typeId(T), Entry{
            .ptr = @ptrCast(set),
            .deinit_fn = deinit_fn,
        });
    }
};

test "init/deinit and registerComponent" {
    const allocator = std.testing.allocator;
    const capacity = 10_000;

    var world = try World.init(allocator, capacity);
    defer world.deinit();
}
