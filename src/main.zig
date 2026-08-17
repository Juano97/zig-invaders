const std = @import("std");
const rl = @import("raylib");

const game = @import("game");

const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) @This() {
        return .{
            .x = x + game.gameConfig.screenWidth / 2,
            .y = y + game.gameConfig.screenHeight / 2,
        };
    }
};

const Rectangle = struct {
    pos: *Point,
    width: i32,
    height: i32,
    speed: f32,

    pub fn draw(self: @This(), color: rl.Color) void {
        rl.drawRectangle(self.pos.x, self.pos.y, self.width, self.height, color);
    }

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }
};
pub fn main() void {
    const screenWidth = game.gameConfig.screenWidth;
    const screenHeight = game.gameConfig.screenHeight;
    rl.initWindow(screenWidth, screenHeight, "Zig Invaders");
    defer rl.closeWindow();

    rl.setTargetFPS(game.gameConfig.targetFPS);

    var shipPosition = Point.init(0, 0);
    var ship = Rectangle{ .pos = &shipPosition, .height = 20, .width = 20, .speed = 5 };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        const movementDirection = game.getMovementVectorByInput();
        shipPosition.x += @intFromFloat(movementDirection.x * ship.speed);
        shipPosition.y += @intFromFloat(movementDirection.y * ship.speed);

        ship.draw(rl.Color.green);
    }
}
