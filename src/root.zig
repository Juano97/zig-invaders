pub const GameConfig = @import("config/game_config.zig").GameConfig;
pub const gameConfig = @import("config/game_config.zig").gameConfig;

pub const Vec3 = @import("math/vec3.zig").Vec3;

pub const Entity = @import("entities/entity.zig").Entity;
pub const SpawnPoint = @import("entities/spawn_point.zig").SpawnPoint;
pub const Actor = @import("entities/actor.zig").Actor;
pub const Character = @import("entities/character.zig").Character;
pub const Player = @import("entities/player/player.zig").Player;

pub const getMovementVectorByInput = @import("input/movement.zig").getMovementVectorByInput;
