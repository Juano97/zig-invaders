const std = @import("std");
const Entity = @import("entity.zig").Entity;

const EMPTY = std.math.maxInt(u32);

pub fn SparseSet(comptime T: type) type {
    return struct {
        sparse: []u32,
        dense: []T,
        entities: []u32,
        count: u32,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !@This() {
            const sparse = try allocator.alloc(u32, capacity);
            errdefer allocator.free(sparse);
            @memset(sparse, EMPTY);

            const dense = try allocator.alloc(T, capacity);
            errdefer allocator.free(dense);

            const entities = try allocator.alloc(u32, capacity);
            @memset(entities, EMPTY);

            return .{
                .sparse = sparse,
                .dense = dense,
                .entities = entities,
                .count = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.sparse);
            self.allocator.free(self.dense);
            self.allocator.free(self.entities);
        }

        pub fn add(self: *@This(), entity: Entity, component: T) !void {
            if (self.count >= self.sparse.len) return error.OutOfCapacity;
            if (self.sparse[entity.index] != EMPTY) return error.ComponentAlreadyExists;

            self.sparse[entity.index] = self.count;
            self.dense[self.count] = component;
            self.entities[self.count] = entity.index;
            self.count += 1;
        }

        pub fn set(self: *@This(), entity: Entity, component: T) !void {
            const dense_index = self.sparse[entity.index];
            if (dense_index != EMPTY) {
                self.dense[dense_index] = component;
            } else {
                try self.add(entity, component);
            }
        }

        pub fn remove(self: *@This(), entity: Entity) !void {
            if (entity.index >= self.sparse.len) return error.OutOfBoundaries;
            if (self.sparse[entity.index] == EMPTY) return error.ComponentDoesNotExist;

            const dense_index_to_remove = self.sparse[entity.index];
            const last_dense_index = self.count - 1;
            const last_entity_index = self.entities[last_dense_index];

            if (dense_index_to_remove != last_dense_index) {
                self.dense[dense_index_to_remove] = self.dense[last_dense_index];
                self.entities[dense_index_to_remove] = last_entity_index;
                self.sparse[last_entity_index] = dense_index_to_remove;
            }

            self.sparse[entity.index] = EMPTY;
            self.count -= 1;
        }

        pub fn has(self: @This(), entity: Entity) bool {
            return self.sparse[entity.index] != EMPTY;
        }

        pub fn get(self: @This(), entity: Entity) ?*const T {
            if (!self.has(entity)) return null;
            return &self.dense[self.sparse[entity.index]];
        }

        pub fn getMutable(self: *@This(), entity: Entity) ?*T {
            if (!self.has(entity)) return null;
            return &self.dense[self.sparse[entity.index]];
        }

        pub fn componentSlice(self: *@This()) []T {
            return self.dense[0..self.count];
        }

        pub fn entitySlice(self: *@This()) []u32 {
            return self.entities[0..self.count];
        }
    };
}

test "SparseSet init / deinit" {
    const allocator = std.testing.allocator;
    const capacity = 10_000;

    var sparseSet = try SparseSet(u32).init(allocator, capacity);
    defer sparseSet.deinit();
}

test "SparseSet add / remove" {
    const allocator = std.testing.allocator;
    const capacity = 10_000;

    var sparseSet = try SparseSet(u32).init(allocator, capacity);
    defer sparseSet.deinit();

    const entity = Entity{ .index = 42, .gen = 0 };
    try sparseSet.add(entity, 99);

    try std.testing.expectEqual(1, sparseSet.count);
    try std.testing.expectEqual(99, sparseSet.dense[0]);
    try std.testing.expectEqual(0, sparseSet.sparse[42]);
    try std.testing.expectEqual(42, sparseSet.entities[0]);

    try sparseSet.remove(entity);

    try std.testing.expectEqual(0, sparseSet.count);
    try std.testing.expectEqual(EMPTY, sparseSet.sparse[42]);

    const entity0 = Entity{ .index = 2, .gen = 0 };
    const entity1 = Entity{ .index = 4, .gen = 0 };
    const entity2 = Entity{ .index = 6, .gen = 0 };

    try sparseSet.set(entity0, 1);
    try sparseSet.set(entity1, 2);
    try sparseSet.set(entity2, 3);

    try sparseSet.remove(entity1);

    try std.testing.expectEqual(2, sparseSet.count);
    try std.testing.expectEqual(1, sparseSet.dense[0]);
    try std.testing.expectEqual(3, sparseSet.dense[1]);
    try std.testing.expectEqual(0, sparseSet.sparse[2]);
    try std.testing.expectEqual(1, sparseSet.sparse[6]);
    try std.testing.expectEqual(2, sparseSet.entities[0]);
    try std.testing.expectEqual(6, sparseSet.entities[1]);

    try std.testing.expectEqual(true, sparseSet.has(entity0));
    try std.testing.expectEqual(false, sparseSet.has(entity1));

    try std.testing.expectEqual(3, sparseSet.get(entity2).?.*);
    try std.testing.expect(sparseSet.get(entity1) == null);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 2, 6 }, sparseSet.entitySlice());
    try std.testing.expectEqualSlices(u32, &[_]u32{ 1, 3 }, sparseSet.componentSlice());

    try sparseSet.set(entity0, 5);

    try std.testing.expectEqual(5, sparseSet.dense[0]);
}
