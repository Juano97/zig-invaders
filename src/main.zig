const std = @import("std");
const rl = @import("raylib");
const player = @import("player.zig").player;
const gameConfig = @import("game-config.zig").gameConfig;

const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }
};

pub fn main() void {
    const screenWidth = gameConfig.screenWidth;
    const screenHeight = gameConfig.screenHeight;

    rl.initWindow(screenWidth, screenHeight, "Zig Invaders");
    defer rl.closeWindow();

    rl.setTargetFPS(gameConfig.targetFPS);

    var rect1 = Rectangle{ .x = 200, .y = 300, .width = 20, .height = 20 };
    var rect2 = Rectangle{ .x = 600, .y = 300, .width = 20, .height = 20 };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        rect1.x += 2;
        rect2.x -= 2;

        rl.drawRectangle(@intFromFloat(rect1.x), @intFromFloat(rect1.y), @intFromFloat(rect1.width), @intFromFloat(rect1.height), rl.Color.green);
        rl.drawRectangle(@intFromFloat(rect2.x), @intFromFloat(rect2.y), @intFromFloat(rect2.width), @intFromFloat(rect2.height), rl.Color.red);

        if (rect1.intersects(rect2)) {
            std.debug.print("Rectangles Intersected!\n", .{});
        }
    }
}
