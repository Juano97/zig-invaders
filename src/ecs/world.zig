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

    fn MutableIterator(comptime types: anytype) type {
        return struct {
            current: u32,
            sparse_sets: [types.len]*anyopaque,
            world: *World,

            fn next(self: *@This()) !?Entity {
                const driver_type = types[0];

                const driver_sparse_set: *SparseSet(driver_type) = @ptrCast(@alignCast(self.sparse_sets[0]));
                const driver_entity_slice = driver_sparse_set.entitySlice();
                while (self.current < driver_entity_slice.len) {
                    const idx = driver_sparse_set.entities[self.current];
                    const entity = Entity{
                        .index = @intCast(idx),
                        .gen = self.world.gens[idx],
                    };
                    var has_all_types = true;
                    for (types[1..], 0..) |T, i| {
                        const sparse_set: *SparseSet(T) = @ptrCast(@alignCast(self.sparse_sets[i + 1]));
                        if (!sparse_set.has(entity)) {
                            has_all_types = false;
                            break;
                        }
                    }
                    self.current += 1;
                    if (has_all_types) return entity;
                }
                return null;
            }
        };
    }

    pub fn queryMutable(self: *@This(), comptime types: anytype) !MutableIterator(types) {
        var sparse_sets: [types.len]*anyopaque = undefined;

        for (types, 0..) |T, i| {
            const entity = self.sets.get(typeId(T)) orelse return error.ComponentNotRegistered;
            sparse_sets[i] = entity.ptr;
        }

        const mutable_iterator = MutableIterator(types){ .current = 0, .sparse_sets = sparse_sets, .world = self };

        return mutable_iterator;
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

/// Drains an iterator into a list of entity indices so tests can compare against
/// the order the driver sparse set stores its entities in.
fn collectIndices(allocator: std.mem.Allocator, it: anytype) ![]u24 {
    var found: std.ArrayList(u24) = .empty;
    errdefer found.deinit(allocator);
    while (try it.next()) |entity| {
        try found.append(allocator, entity.index);
    }
    return found.toOwnedSlice(allocator);
}

test "queryMutable single component" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: u8,
        y: u8,
    };

    try world.registerComponent(Position, capacity);

    const entity0 = try world.spawn();
    _ = try world.spawn(); // entity without a Position, must be skipped
    const entity2 = try world.spawn();

    try world.set(entity0, Position, .{ .x = 0, .y = 0 });
    try world.set(entity2, Position, .{ .x = 2, .y = 2 });

    var it = try world.queryMutable(.{Position});
    const found = try collectIndices(allocator, &it);
    defer allocator.free(found);

    try std.testing.expectEqualSlices(u24, &[_]u24{ entity0.index, entity2.index }, found);
}

test "queryMutable yields the current generation" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: u8,
    };

    try world.registerComponent(Position, capacity);

    const entity0 = try world.spawn();
    try world.destroy(entity0);

    const entity1 = try world.spawn();
    try std.testing.expectEqual(entity0.index, entity1.index);
    try std.testing.expectEqual(1, entity1.gen);

    try world.set(entity1, Position, .{ .x = 7 });

    var it = try world.queryMutable(.{Position});
    const first = (try it.next()).?;

    try std.testing.expect(first.eql(entity1));
    try std.testing.expect(try it.next() == null);
}

test "queryMutable intersects multiple components" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: i32,
    };
    const Velocity = struct {
        dx: i32,
    };
    const Health = struct {
        hp: u8,
    };

    try world.registerComponent(Position, capacity);
    try world.registerComponent(Velocity, capacity);
    try world.registerComponent(Health, capacity);

    const entity0 = try world.spawn();
    const entity1 = try world.spawn();
    const entity2 = try world.spawn();
    const entity3 = try world.spawn();

    // entity0: Position + Velocity
    // entity1: Position only
    // entity2: Position + Velocity + Health
    // entity3: Velocity only
    try world.set(entity0, Position, .{ .x = 0 });
    try world.set(entity0, Velocity, .{ .dx = 1 });
    try world.set(entity1, Position, .{ .x = 10 });
    try world.set(entity2, Position, .{ .x = 20 });
    try world.set(entity2, Velocity, .{ .dx = 2 });
    try world.set(entity2, Health, .{ .hp = 100 });
    try world.set(entity3, Velocity, .{ .dx = 3 });

    var pos_vel = try world.queryMutable(.{ Position, Velocity });
    const pos_vel_found = try collectIndices(allocator, &pos_vel);
    defer allocator.free(pos_vel_found);
    try std.testing.expectEqualSlices(u24, &[_]u24{ entity0.index, entity2.index }, pos_vel_found);

    // The first type drives the iteration, so the same set is reachable from
    // either side of the intersection.
    var vel_pos = try world.queryMutable(.{ Velocity, Position });
    const vel_pos_found = try collectIndices(allocator, &vel_pos);
    defer allocator.free(vel_pos_found);
    try std.testing.expectEqualSlices(u24, &[_]u24{ entity0.index, entity2.index }, vel_pos_found);

    var all_three = try world.queryMutable(.{ Velocity, Position, Health });
    const all_three_found = try collectIndices(allocator, &all_three);
    defer allocator.free(all_three_found);
    try std.testing.expectEqualSlices(u24, &[_]u24{entity2.index}, all_three_found);
}

test "queryMutable returns no entities when nothing matches" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: u8,
    };
    const Velocity = struct {
        dx: u8,
    };

    try world.registerComponent(Position, capacity);
    try world.registerComponent(Velocity, capacity);

    // Nothing has any component yet.
    var empty = try world.queryMutable(.{Position});
    try std.testing.expect(try empty.next() == null);

    const entity0 = try world.spawn();
    const entity1 = try world.spawn();
    try world.set(entity0, Position, .{ .x = 1 });
    try world.set(entity1, Velocity, .{ .dx = 1 });

    // Disjoint components never intersect.
    var disjoint = try world.queryMutable(.{ Position, Velocity });
    try std.testing.expect(try disjoint.next() == null);
}

test "queryMutable errors on unregistered component" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: u8,
    };
    const Velocity = struct {
        dx: u8,
    };

    try std.testing.expectError(error.ComponentNotRegistered, world.queryMutable(.{Position}));

    try world.registerComponent(Position, capacity);

    // The driver is registered but a filter type is not.
    try std.testing.expectError(error.ComponentNotRegistered, world.queryMutable(.{ Position, Velocity }));
}

test "queryMutable allows mutating components while iterating" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: i32,
    };
    const Velocity = struct {
        dx: i32,
    };

    try world.registerComponent(Position, capacity);
    try world.registerComponent(Velocity, capacity);

    const entity0 = try world.spawn();
    const entity1 = try world.spawn();
    const entity2 = try world.spawn();

    try world.set(entity0, Position, .{ .x = 0 });
    try world.set(entity0, Velocity, .{ .dx = 5 });
    try world.set(entity1, Position, .{ .x = 100 });
    try world.set(entity2, Position, .{ .x = 50 });
    try world.set(entity2, Velocity, .{ .dx = -10 });

    var it = try world.queryMutable(.{ Position, Velocity });
    var visited: u32 = 0;
    while (try it.next()) |entity| {
        const velocity = try world.get(entity, Velocity);
        const position = try world.getMutable(entity, Position);
        position.x += velocity.dx;
        visited += 1;
    }

    try std.testing.expectEqual(2, visited);
    try std.testing.expectEqual(5, (try world.get(entity0, Position)).x);
    try std.testing.expectEqual(100, (try world.get(entity1, Position)).x); // untouched
    try std.testing.expectEqual(40, (try world.get(entity2, Position)).x);
}

test "queryMutable reflects removed components and destroyed entities" {
    const allocator = std.testing.allocator;
    const capacity = 128;

    var world = try World.init(allocator, capacity);
    defer world.deinit();

    const Position = struct {
        x: u8,
    };

    try world.registerComponent(Position, capacity);

    const entity0 = try world.spawn();
    const entity1 = try world.spawn();
    const entity2 = try world.spawn();

    try world.set(entity0, Position, .{ .x = 0 });
    try world.set(entity1, Position, .{ .x = 1 });
    try world.set(entity2, Position, .{ .x = 2 });

    try world.remove(entity1, Position);

    // Removal swaps the last dense element into the freed slot, so entity2 now
    // sits where entity1 was.
    var after_remove = try world.queryMutable(.{Position});
    const after_remove_found = try collectIndices(allocator, &after_remove);
    defer allocator.free(after_remove_found);
    try std.testing.expectEqualSlices(u24, &[_]u24{ entity0.index, entity2.index }, after_remove_found);

    try world.destroy(entity0);

    var after_destroy = try world.queryMutable(.{Position});
    const after_destroy_found = try collectIndices(allocator, &after_destroy);
    defer allocator.free(after_destroy_found);
    try std.testing.expectEqualSlices(u24, &[_]u24{entity2.index}, after_destroy_found);
}
