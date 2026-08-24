const std = @import("std");
const rl = @import("raylib");

const game = @import("game");

fn drawRectangleWrapper(screenW: i32, screenH: i32, posX: i32, posY: i32, width: i32, height: i32, color: rl.Color) void {
    rl.drawRectangle(posX + @divTrunc(screenW, 2), posY + @divTrunc(screenH, 2), width, height, color);
}

pub fn main() !void {
    const screenWidth = game.gameConfig.screenWidth;
    const screenHeight = game.gameConfig.screenHeight;
    rl.initWindow(screenWidth, screenHeight, "Zig Invaders");
    defer rl.closeWindow();

    rl.setTargetFPS(game.gameConfig.targetFPS);

    const allocator = std.heap.page_allocator;
    const capacity = 32;
    var world = try game.World.init(allocator, capacity);
    defer world.deinit();

    try world.registerComponent(game.Position, capacity);
    try world.registerComponent(game.Velocity, capacity);
    try world.registerComponent(game.Sprite, capacity);

    const player = try world.spawn();
    const initialVector: game.Vec3 = .{ .x = 0, .y = 0, .z = 0 };
    try world.set(player, game.Position, .{ .v = initialVector });
    try world.set(player, game.Velocity, .{ .v = initialVector });
    try world.set(player, game.Sprite, .{ .height = 20, .width = 20 });

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        const movementDirection = game.getMovementVectorByInput();

        const mutablePlayerPosition = try world.getMutable(player, game.Position);
        const mutablePlayerSprite = try world.getMutable(player, game.Sprite);

        const speed = 5;
        const velocity: game.Velocity = .{ .v = .{ .x = movementDirection.x * speed, .y = movementDirection.y * speed, .z = 0 } };

        mutablePlayerPosition.v.x += velocity.v.x;
        mutablePlayerPosition.v.y += velocity.v.y;

        drawRectangleWrapper(screenWidth, screenHeight, @intFromFloat(mutablePlayerPosition.v.x), @intFromFloat(mutablePlayerPosition.v.y), mutablePlayerSprite.width, mutablePlayerSprite.height, rl.Color.green);
    }
}
