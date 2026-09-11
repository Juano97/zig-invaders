const std = @import("std");
const rl = @import("raylib");

const game = @import("game");

pub fn main() !void {
    const screenWidth = game.gameConfig.screenWidth;
    const screenHeight = game.gameConfig.screenHeight;
    rl.initWindow(screenWidth, screenHeight, "Zig Invaders");
    defer rl.closeWindow();

    rl.setTargetFPS(game.gameConfig.targetFPS);

    var inputState: game.InputState = .{};

    const allocator = std.heap.page_allocator;
    const capacity = 32;
    var world = try game.World.init(allocator, capacity);
    defer world.deinit();

    try world.registerComponent(game.Position, capacity);
    try world.registerComponent(game.Velocity, capacity);
    try world.registerComponent(game.Sprite, capacity);

    const player = try world.spawn();
    const initialVectorPosition: game.Vec2 = .{ .x = game.playerConfig.playerStartX, .y = game.playerConfig.playerStartY };
    const initialVectorVelocity: game.Vec2 = .{ .x = 0, .y = 0 };
    try world.set(player, game.Position, .{ .v = initialVectorPosition });
    try world.set(player, game.Velocity, .{ .v = initialVectorVelocity });
    try world.set(player, game.Sprite, .{ .height = @intFromFloat(game.playerConfig.playerHeight), .width = @intFromFloat(game.playerConfig.playerWidth) });

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        const movementVector = inputState.poll();

        const mutablePlayerPosition = try world.getMutable(player, game.Position);
        const mutablePlayerVelocity = try world.getMutable(player, game.Velocity);
        const mutablePlayerSprite = try world.getMutable(player, game.Sprite);

        const normMovementVector = movementVector.normalize();

        const speed = game.playerConfig.playerSpeed;
        mutablePlayerVelocity.v.x = normMovementVector.x * speed;
        mutablePlayerVelocity.v.y = normMovementVector.y * speed;

        mutablePlayerPosition.v.x = std.math.clamp(mutablePlayerPosition.v.x + mutablePlayerVelocity.v.x, 0, @as(f32, @floatFromInt(game.gameConfig.screenWidth - mutablePlayerSprite.width)));
        mutablePlayerPosition.v.y = std.math.clamp(mutablePlayerPosition.v.y + mutablePlayerVelocity.v.y, 0, @as(f32, @floatFromInt(game.gameConfig.screenHeight - mutablePlayerSprite.height)));

        rl.drawRectangle(@intFromFloat(mutablePlayerPosition.v.x), @intFromFloat(mutablePlayerPosition.v.y), mutablePlayerSprite.width, mutablePlayerSprite.height, rl.Color.green);
    }
}
