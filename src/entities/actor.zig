const game = @import("game");

pub const Actor = struct {
    position: game.Vec3,
    direction: game.Vec3,
    speed: f32,
};
