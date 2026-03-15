const rl = @import("raylib");
const player = @import("player.zig").player;
const gameConfig = @import("game-config.zig").gameConfig;

pub fn main() void {
    const screenWidth = gameConfig.screenWidth;
    const screenHeight = gameConfig.screenHeight;

    rl.initWindow(screenWidth, screenHeight, "Zig Invaders");
    defer rl.closeWindow();

    rl.setTargetFPS(gameConfig.targetFPS);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        rl.drawText("Zig Invaders!", 300, 250, 40, rl.Color.green);
    }
}
