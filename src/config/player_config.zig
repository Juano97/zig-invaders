const gameConfig = @import("game_config.zig").gameConfig;

pub const PlayerConfig = struct {
    playerWidth: f32,
    playerHeight: f32,
    playerStartX: f32,
    playerStartY: f32,
    playerSpeed: f32,
};

pub const playerConfig: PlayerConfig = PlayerConfig{
    .playerWidth = 20,
    .playerHeight = 20,
    .playerStartX = @as(f32, @floatFromInt(gameConfig.screenWidth)) / 2,
    .playerStartY = @as(f32, @floatFromInt(gameConfig.screenHeight)) - (@as(f32, @floatFromInt(gameConfig.screenHeight)) / 10),
    .playerSpeed = 5,
};
