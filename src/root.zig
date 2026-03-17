pub const GameConfig = @import("config/game_config.zig").GameConfig;
pub const gameConfig = @import("config/game_config.zig").gameConfig;

pub const Vec3 = @import("math/vec3.zig").Vec3;

pub const Entity = @import("ecs/entity.zig").Entity;
pub const Storage = @import("ecs/storage.zig").Storage;

pub const getMovementVectorByInput = @import("input/movement.zig").getMovementVectorByInput;
