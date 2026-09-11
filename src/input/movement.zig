const rl = @import("raylib");
const Vec2 = @import("../math/vec2.zig").Vec2;

const DEADZONE = 0.1;

pub const InputState = struct {
    last_x: ?bool = null,
    last_y: ?bool = null,

    fn getAxisMovement(positive: bool, negative: bool, last: *?bool) f32 {
        if (negative and positive) {
            if (last.* == false) {
                return 1;
            } else if (last.* == true) {
                return -1;
            } else {
                return 0;
            }
        } else {
            if (negative) {
                last.* = false;
                return -1;
            } else if (positive) {
                last.* = true;
                return 1;
            } else {
                last.* = null;
                return 0;
            }
        }
    }

    pub fn poll(self: *@This()) Vec2 {
        var result: Vec2 = .{ .x = 0, .y = 0 };

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

        const downKey = .{
            .left = rl.isKeyDown(rl.KeyboardKey.a) or rl.isKeyDown(rl.KeyboardKey.left),
            .right = rl.isKeyDown(rl.KeyboardKey.d) or rl.isKeyDown(rl.KeyboardKey.right),
            .down = rl.isKeyDown(rl.KeyboardKey.s) or rl.isKeyDown(rl.KeyboardKey.down),
            .up = rl.isKeyDown(rl.KeyboardKey.w) or rl.isKeyDown(rl.KeyboardKey.up),
        };

        const mov_x = getAxisMovement(downKey.right, downKey.left, &self.last_x);
        const mov_y = getAxisMovement(downKey.down, downKey.up, &self.last_y);

        result.x += mov_x;
        result.y += mov_y;

        return result;
    }
};
