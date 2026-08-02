# MENTOR.md

Zig Invaders — a Space Invaders clone in Zig 0.15.2, built on raylib-zig for windowing/input/drawing. Solo learning project; author is building both the game and a from-scratch ECS as an exercise, so expect deliberate "do it myself" choices (custom sparse-set ECS instead of a library) over shortcuts.

**Entry points**
- `src/main.zig` — `main()`. Currently a standalone prototype: opens an 800x600 window, draws one green rectangle ("ship") moved by keyboard/gamepad input, no game loop structure beyond that yet. It does **not** use the ECS (`World`/`Entity`) at all — the `Point`/`Rectangle` types here are throwaway and duplicate what the ECS is meant to replace.
- `src/root.zig` — the library module's public surface; re-exports `GameConfig`, `Vec3`, `Entity`, `Storage`, `getMovementVectorByInput`. If you add a new file under `src/`, it's invisible outside its own file until re-exported here.
- `build.zig` defines two modules: `zig_invaders` (rooted at `src/root.zig`) and `game` (also rooted at `src/root.zig`, imported into the exe as `@import("game")`). They're currently identical exports under two names — a bit redundant, watch for this when adding new exports/imports so they land in the right module.

**Build & test**
- `zig build run` — builds and runs the game.
- `zig build test` — runs two separate test binaries in parallel: one for `mod` (`src/root.zig`) and one for `exe.root_module` (`src/main.zig`). Tests currently live in `src/ecs/storage.zig` and `src/ecs/world.zig` as `test` blocks — that's where to add new ECS tests.
- Requires network on first build to fetch the `raylib_zig` dependency (pinned in `build.zig.zon`); after that it's cached and offline-friendly.

**How the pieces fit**
- ECS is a classic sparse-set design: `src/ecs/entity.zig` defines `Entity` as `{index: u24, gen: u8}` (packed) — the generation field is how stale handles get detected after reuse.
- `src/ecs/storage.zig`'s `SparseSet(T)` is the per-component-type backing store: `sparse[entity.index]` → dense array slot, with swap-remove for O(1) deletion. Solid and tested (see the two `test` blocks at the bottom of the file).
- `src/ecs/world.zig`'s `World` owns one `SparseSet` per registered component type, type-erased via `typeId()` (pointer identity of `@typeName(T)`) into an `Entry{ptr, deinit_fn}` stored in an `AutoHashMap`. Every accessor (`set`/`get`/`getMutable`/`remove`) re-checks `entity.gen` against `World.gens[index]` before touching storage — that's the invariant holding the whole handle-safety story together; don't bypass it.
- `queryMutable` (world.zig:134) is broken/unfinished: `entry.len` doesn't exist on `Entry`, `u8.maxValue` isn't valid Zig, and it never returns anything. This is likely the next thing to build — don't assume it compiles or works.

**Where someone would go wrong**
- `main.zig` bypasses the ECS entirely; wiring it up to spawn a player `Entity` via `World` is unfinished work, not an oversight to "fix" quietly.
- `game_config.zig` already has fields for shields, invaders, bullets that nothing reads yet — `main.zig` hardcodes ship size (20x20) instead of `playerWidth`/`playerHeight`. Config drift to watch for as features land.
- `World.spawn`'s free-slot reuse and `gens` growth only up to `capacity` set at `init` — there's no resize path, so `error.GensFull` is a real ceiling, not defensive-only code.
