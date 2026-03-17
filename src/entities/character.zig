const game = @import("game");

pub const Character = struct {
    spawnPoint: game.Vec3,
    position: game.Vec3,
    direction: game.Vec3,
    speed: f32,
    health: f32,
};
