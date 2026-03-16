const std = @import("std");
const rl = @import("raylib");
const player = @import("player.zig").player;
const gameConfig = @import("game-config.zig").gameConfig;
const getMovementVectorByInput = @import("movement-by-input.zig").getMovementVectorByInput;

const Point = struct {
    x: i32,
    y: i32,

    pub fn normalize(self: @This()) @This() {
        return .{
            .x = self.x + gameConfig.screenWidth / 2,
            .y = self.y + gameConfig.screenHeight / 2,
        };
    }
};

const Rectangle = struct {
    pos: *Point,
    width: i32,
    height: i32,

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
    const screenWidth = gameConfig.screenWidth;
    const screenHeight = gameConfig.screenHeight;

    rl.initWindow(screenWidth, screenHeight, "Zig Invaders");
    defer rl.closeWindow();

    rl.setTargetFPS(gameConfig.targetFPS);

    var shipPosition = (Point{ .x = 0, .y = 0 }).normalize();
    var ship = Rectangle{ .pos = &shipPosition, .height = 20, .width = 20 };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        const movementDirection = getMovementVectorByInput();

        if (movementDirection.x != 0 or movementDirection.y != 0) {
            std.debug.print("Movement : {d}, {d}\n", .{
                movementDirection.x,
                movementDirection.y,
            });
        }
        ship.draw(rl.Color.green);
    }
}
