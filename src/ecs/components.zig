const Vec2 = @import("../math/vec2.zig").Vec2;

pub const Position = struct { v: Vec2 };
pub const Velocity = struct { v: Vec2 };
pub const Sprite = struct {
    width: i32,
    height: i32,
};
