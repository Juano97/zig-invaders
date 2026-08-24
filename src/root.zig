pub const GameConfig = @import("config/game_config.zig").GameConfig;
pub const gameConfig = @import("config/game_config.zig").gameConfig;

pub const Vec3 = @import("math/vec3.zig").Vec3;

pub const Entity = @import("ecs/entity.zig").Entity;
pub const SparseSet = @import("ecs/storage.zig").SparseSet;
pub const World = @import("ecs/world.zig").World;

pub const Position = @import("ecs/components.zig").Position;
pub const Velocity = @import("ecs/components.zig").Velocity;
pub const Sprite = @import("ecs/components.zig").Sprite;

pub const getMovementVectorByInput = @import("input/movement.zig").getMovementVectorByInput;
