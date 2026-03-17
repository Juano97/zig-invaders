const game = @import("root");

pub const Player = struct {
    character: game.Character,
    baseDamage: f32,
    baseFiringRate: f32,
};

// pub const player = Player{ .character = .{
//         .spawnPoint = .{
//             .x = 0,
//             .y = game.gameConfig.
//         }
//     }
// };
