const Vec3 = @import("../math/vec3.zig").Vec3;

pub const Position = struct { v: Vec3 };
pub const Velocity = struct { v: Vec3 };
pub const Sprite = struct {
    width: i32,
    height: i32,
};
