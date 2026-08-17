const rl = @import("raylib");

const DEADZONE = 0.1;

pub const MovementVector = struct {
    x: f32,
    y: f32,
};

pub fn getMovementVectorByInput() MovementVector {
    var result = MovementVector{ .x = 0, .y = 0 };

    if (rl.isGamepadAvailable(0)) {
        const x = rl.getGamepadAxisMovement(0, rl.GamepadAxis.left_x);
        const y = rl.getGamepadAxisMovement(0, rl.GamepadAxis.left_y);

        if (@abs(x) > DEADZONE) {
            result.x = x;
        }

        if (@abs(y) > DEADZONE) {
            result.y = y;
        }
    }

    if (rl.isKeyDown(rl.KeyboardKey.a) or rl.isKeyDown(rl.KeyboardKey.left)) {
        result.x -= 1;
    }

    if (rl.isKeyDown(rl.KeyboardKey.d) or rl.isKeyDown(rl.KeyboardKey.right)) {
        result.x += 1;
    }

    if (rl.isKeyDown(rl.KeyboardKey.s) or rl.isKeyDown(rl.KeyboardKey.down)) {
        result.y += 1;
    }

    if (rl.isKeyDown(rl.KeyboardKey.w) or rl.isKeyDown(rl.KeyboardKey.up)) {
        result.y -= 1;
    }

    return result;
}
