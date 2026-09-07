# MENTOR.md

Zig Invaders — a Space Invaders clone in Zig, built on raylib-zig for windowing/input/drawing. Solo learning project; author is building both the game and a from-scratch ECS as an exercise, so expect deliberate "do it myself" choices (custom sparse-set ECS instead of a library) over shortcuts. `build.zig.zon` pins `minimum_zig_version = "0.16.0"` — if your toolchain is older, that's why it won't build.

**Entry points**
- `src/main.zig` — `main()`. Now wired to the ECS: sizes the window from `gameConfig` (`screenWidth`/`screenHeight`/`targetFPS`), builds a `World` (capacity 32), registers `Position`/`Velocity`/`Sprite`, spawns one player `Entity`, then each frame reads `getMovementVectorByInput()`, mutates the player's `Position` in place, and draws it as a green rectangle. No system layer yet — the loop does everything inline and never calls `queryMutable`. It `@import("game")`, not `@import("zig_invaders")`.
- `src/root.zig` — the shared module surface. Re-exports `GameConfig`, `gameConfig`, `Vec3`, `Entity`, `SparseSet`, `World`, `Position`, `Velocity`, `Sprite`, `getMovementVectorByInput`. A new file under `src/` is invisible outside itself until re-exported here.
- `build.zig` defines two modules, both rooted at `src/root.zig`: `zig_invaders` (has `.target`, **no** `raylib` import) and `game` (imported into the exe as `@import("game")`, **does** import `raylib`). They are no longer interchangeable — see Build & test.

**Build & test**
- `zig build run` — builds and runs the game.
- `zig build test` — runs two test binaries in parallel: `mod` (rooted at `src/root.zig`) and `exe.root_module` (`src/main.zig`). All `test` blocks live in `src/ecs/storage.zig` and `src/ecs/world.zig` — that's where to add ECS tests.
- Trap: `src/root.zig` now transitively pulls in `src/input/movement.zig`, whose `@import("raylib")` the `zig_invaders`/`mod` module does not provide. If `zig build test` fails only on the `mod` side, that asymmetry in `build.zig` (lines ~39 vs ~167) is why — fix by giving `mod` the `raylib` import too, or by keeping raylib-dependent code out of the `root.zig` re-export path.
- First build needs network to fetch `raylib_zig` (pinned in `build.zig.zon`); cached and offline-friendly after.

**How the pieces fit**
- `src/ecs/entity.zig`: `Entity` is a packed `{index: u24, gen: u8}`, plus `Entity.invalid` and `eql`. Use `.eql()` not `==` for handles — it's what the tests do.
- `src/ecs/storage.zig`: `SparseSet(T)` is the per-component backing store — `sparse[entity.index]` → dense slot, swap-remove for O(1) deletion. `componentSlice()`/`entitySlice()` expose the live dense range. Solid and tested.
- `src/ecs/world.zig`: `World` owns one `SparseSet` per registered type, type-erased via `typeId()` (pointer identity of `@typeName(T)`) into an `Entry{ptr, deinit_fn, remove_fn}` in an `AutoHashMap`. Every accessor (`set`/`get`/`getMutable`/`remove`/`destroy`) re-checks `entity.gen` against `World.gens[index]` first — that invariant is the whole handle-safety story; don't bypass it. `destroy` walks every `Entry` and calls `remove_fn`, so a destroyed entity's components are cleaned from every `SparseSet`, not just its `gens` slot bumped.
- `queryMutable` (world.zig:182) returns a `MutableIterator`; `.next()` yields `?Entity` at the current generation, and you call `world.get`/`getMutable` on it inside the loop. First type in the tuple is the "driver" whose dense array is walked; the rest are intersected via `has()`. Result order follows the driver's dense order, which shifts under swap-remove — see the "reflects removed components and destroyed entities" test (world.zig:519). Well covered by world.zig:311-555.

**Where someone would go wrong**
- `main.zig` sets a `Velocity` component that nothing reads — the loop derives velocity from input locally and applies it straight to `Position`. Building a real movement system over `queryMutable(.{ Velocity, Position })` is unfinished work, not an oversight.
- `main.zig` hardcodes the sprite at 20x20; config's `playerWidth`/`playerHeight` are 40x20 and `playerStartY` (550) is unused. `Sprite.width`/`.height` are `i32` while the config fields are `f32`, so a cast has to land wherever they get connected.
- `game_config.zig` still has shield/invader/bullet fields nothing reads yet.
- `main.zig`'s `drawRectangleWrapper` offsets everything by half the screen, so world origin `(0,0)` is screen center and the player spawns there — intentional-looking, easy to trip on when you add absolute positioning.
- `World.spawn`: `gens` is sized once at `init` (capacity), no resize path — `error.GensFull` is a real ceiling, and `main.zig` picks only 32.
- `main.zig` uses `std.heap.page_allocator` (no leak detection); the tests use `std.testing.allocator`, which does detect leaks.
