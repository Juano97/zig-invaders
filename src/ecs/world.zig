const std = @import("std");
const Entity = @import("entity.zig").Entity;
const SparseSet = @import("storage.zig").SparseSet;

fn typeId(comptime T: type) usize {
    const ptr: *const anyopaque = @ptrCast(@typeName(T));
    return @intFromPtr(ptr);
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
        remove_fn: *const fn (ptr: *anyopaque, entity: Entity) void,
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

        const sparse_set = try self.allocator.create(SparseSet(T));
        errdefer self.allocator.destroy(sparse_set);
        sparse_set.* = try SparseSet(T).init(self.allocator, capacity);

        const deinit_fn = struct {
            fn f(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                const s: *SparseSet(T) = @ptrCast(@alignCast(ptr));
                s.deinit();
                allocator.destroy(s);
            }
        }.f;

        const remove_fn = struct {
            fn f(ptr: *anyopaque, entity: Entity) void {
                const s: *SparseSet(T) = @ptrCast(@alignCast(ptr));
                s.remove(entity) catch |err| switch (err) {
                    error.ComponentDoesNotExist => {},
                    else => unreachable,
                };
            }
        }.f;

        try self.sets.put(typeId(T), Entry{
            .ptr = @ptrCast(sparse_set),
            .deinit_fn = deinit_fn,
            .remove_fn = remove_fn,
        });
    }

    pub fn spawn(self: *@This()) !Entity {
        const free_slot = self.free_slots.pop();
        if (free_slot == null and self.count == self.gens.len) return error.GensFull;
        if (free_slot == null) {
            const index = self.count;
            self.count += 1;
            const gen_value = self.gens[index];
            return Entity{
                .index = @intCast(index),
                .gen = gen_value,
            };
        } else {
            const slot = free_slot.?;
            const gen_value = self.gens[slot];
            return Entity{
                .index = @intCast(slot),
                .gen = gen_value,
            };
        }
    }

    pub fn destroy(self: *@This(), entity: Entity) !void {
        if (self.gens[entity.index] != entity.gen) return error.EntityStale;
        var it = self.sets.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.remove_fn(entry.value_ptr.ptr, entity);
        }
        self.gens[entity.index] += 1;
        try self.free_slots.append(self.allocator, entity.index);
    }

    pub fn set(self: @This(), entity: Entity, comptime T: type, value: T) !void {
        if (entity.gen != self.gens[entity.index]) return error.EntityStale;

        const entry = self.sets.get(typeId(T)) orelse return error.ComponentNotRegistered;

        const sparse_set: *SparseSet(T) = @ptrCast(@alignCast(entry.ptr));
        try sparse_set.set(entity, value);
    }

    pub fn get(self: @This(), entity: Entity, comptime T: type) !*const T {
        if (entity.gen != self.gens[entity.index]) return error.EntityStale;

        const entry = self.sets.get(typeId(T)) orelse return error.ComponentNotRegistered;

        const sparse_set: *SparseSet(T) = @ptrCast(@alignCast(entry.ptr));
        return sparse_set.get(entity) orelse return error.ComponentNotFound;
    }

    pub fn getMutable(self: *@This(), entity: Entity, comptime T: type) !*T {
        if (entity.gen != self.gens[entity.index]) return error.EntityStale;

        const entry = self.sets.get(typeId(T)) orelse return error.ComponentNotRegistered;

        const sparse_set: *SparseSet(T) = @ptrCast(@alignCast(entry.ptr));
        return sparse_set.getMutable(entity) orelse return error.ComponentNotFound;
    }

    pub fn remove(self: *@This(), entity: Entity, comptime T: type) !void {
        if (entity.gen != self.gens[entity.index]) return error.EntityStale;

        const entry = self.sets.get(typeId(T)) orelse return error.ComponentNotRegistered;

        const sparse_set: *SparseSet(T) = @ptrCast(@alignCast(entry.ptr));
        try sparse_set.remove(entity);
    }

    pub fn queryMutable(self: *@This(), comptime types: anytype) ![]Entity {
        _ = self;
        _ = types;
        return &.{};
    }
};

test "init/deinit and registerComponent" {
    const allocator = std.testing.allocator;
    const capacity = 10_000;

    var world = try World.init(allocator, capacity);

    const Position = struct {
        x: u8,
        y: u8,
    };

    try world.registerComponent(Position, capacity);
    try std.testing.expectError(error.ComponentAlreadyRegistered, world.registerComponent(Position, capacity));

    defer world.deinit();
}

test "spawn/destroy" {
    const allocator = std.testing.allocator;
    const capacity = 10_000;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const entity0 = try world.spawn();
    const entity1 = try world.spawn();
    const entity2 = try world.spawn();
    const entity3 = try world.spawn();
    const entity4 = try world.spawn();

    try std.testing.expectEqual(0, entity0.index);
    try std.testing.expectEqual(1, entity1.index);
    try std.testing.expectEqual(2, entity2.index);
    try std.testing.expectEqual(3, entity3.index);
    try std.testing.expectEqual(4, entity4.index);

    try std.testing.expectEqual(5, world.count);

    try world.destroy(entity1);
    try std.testing.expectEqual(1, world.free_slots.items.len);
    try std.testing.expectEqual(1, world.gens[entity1.index]);

    const entity6 = try world.spawn();

    try std.testing.expectEqual(0, world.free_slots.items.len);
    try std.testing.expectEqual(1, entity6.gen);

    try world.destroy(entity6);

    const entity7 = try world.spawn();

    try std.testing.expectEqual(0, world.free_slots.items.len);
    try std.testing.expectEqual(2, entity7.gen);
    try std.testing.expectEqual(1, entity7.index);

    try std.testing.expectError(error.EntityStale, world.destroy(entity6));
}

test "get/set/remove/getMutable" {
    const allocator = std.testing.allocator;
    const capacity = 10_000;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const entity0 = try world.spawn();
    const entity1 = try world.spawn();
    const Position = struct {
        x: u8,
        y: u8,
    };
    const Velocity = struct {
        d: u8,
    };

    try world.registerComponent(Position, capacity);
    try world.set(entity0, Position, .{
        .x = 0,
        .y = 1,
    });

    const position0 = try world.get(entity0, Position);
    try std.testing.expectEqual(1, position0.y);

    try world.set(entity0, Position, .{
        .x = 1,
        .y = 2,
    });
    const position1 = try world.get(entity0, Position);
    try std.testing.expectEqual(2, position1.y);

    var position2 = try world.getMutable(entity0, Position);
    position2.x = 5;

    try std.testing.expectEqual(5, position2.x);
    try std.testing.expectError(error.ComponentNotFound, world.getMutable(entity1, Position));

    try world.remove(entity0, Position);

    try std.testing.expectError(error.ComponentNotFound, world.getMutable(entity0, Position));
    try std.testing.expectError(error.ComponentNotRegistered, world.remove(entity1, Velocity));
}
