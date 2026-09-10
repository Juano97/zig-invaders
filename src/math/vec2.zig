pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub const zero: Vec2 = .{ .x = 0, .y = 0 };

    fn length(self: @This()) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn normalize(self: @This()) @This() {
        const len = self.length();
        if (len == 0) {
            return @This().zero;
        }
        const result: @This() = .{
            .x = self.x / len,
            .y = self.y / len,
        };
        return result;
    }
};
