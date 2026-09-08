pub const GameConfig = struct {
    screenWidth: i32,
    screenHeight: i32,
    targetFPS: i32,
    bulletWidth: f32,
    bulletHeight: f32,
    shieldStartX: f32,
    shieldY: f32,
    shieldWidth: f32,
    shieldHeight: f32,
    shieldSpacing: f32,
    invaderStartX: f32,
    invaderStartY: f32,
    invaderWidth: f32,
    invaderHeight: f32,
    invaderSpacingX: f32,
    invaderSpacingY: f32,
};

pub const PlayerConfig = struct {
    playerWidth: f32,
    playerHeight: f32,
    playerStartX: f32,
    playerStartY: f32,
    playerStartZ: f32,
    playerSpeed: f32,
};

pub const gameConfig = GameConfig{
    .screenWidth = 800,
    .screenHeight = 600,
    .targetFPS = 60,
    .bulletWidth = 4,
    .bulletHeight = 10,
    .shieldStartX = 100,
    .shieldY = 450,
    .shieldWidth = 60,
    .shieldHeight = 40,
    .shieldSpacing = 120,
    .invaderStartX = 100,
    .invaderStartY = 100,
    .invaderWidth = 40,
    .invaderHeight = 20,
    .invaderSpacingX = 10,
    .invaderSpacingY = 10,
};

pub const playerConfig: PlayerConfig = PlayerConfig{
    .playerWidth = 20,
    .playerHeight = 20,
    .playerStartX = @as(f32, @floatFromInt(gameConfig.screenWidth)) / 2,
    .playerStartY = @as(f32, @floatFromInt(gameConfig.screenHeight)) - (@as(f32, @floatFromInt(gameConfig.screenHeight)) / 10),
    .playerStartZ = 0,
    .playerSpeed = 5,
};
