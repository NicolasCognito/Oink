# Oink Dev Cheatsheet (LÖVE + tiny-ecs + busted)

This repo is set up to develop game logic with tiny-ecs, run the game in LÖVE, and test logic headlessly with busted.

## What’s Set Up
- Local Lua toolchain under `./.lua` (via hererocks) with Lua 5.4, LuaRocks, busted, and luacov.
- tiny-ecs vendored in `libs/` and used by systems/world.
- Game orchestration split into modules (game/world/components/systems).
- Tests run without LÖVE; only effect systems (e.g., input, draw) need `love.*`.

## Project Layout
- `main.lua`: LÖVE entry. Sets require paths, delegates to `src/game.lua`.
- `src/game.lua`: Orchestrates world lifecycle (`Game.load/update/draw`).
- `src/world.lua`: Builds tiny-ecs world; registers systems.
- `src/components/`: Component factories (plain data tables).
- `src/systems/`: Systems (prefer pure logic; effect systems may use `love.*`).
- `libs/`: Vendored libraries (tiny-ecs at `libs/tiny.lua`).
- `spec/`: Busted tests (`spec/support/love_stub.lua` available if needed).
- `.busted`: Configures search paths and uses `./.lua/bin/lua`.

## Running Things
- Run game: `love .` (from repo root).
- Run tests: `.lua/bin/busted -c` (uses `.busted` config and prints coverage if available).
- Install a Lua rock locally: `.lua/bin/luarocks install <rock>`.

## Module Resolution
`main.lua` defers configuring require paths until `love.load()`. It appends:
- `src/?.lua; src/?/init.lua`
- `libs/?.lua; libs/?/init.lua`
- `libs/tiny-ecs/?.lua; libs/tiny-ecs/?/init.lua`

Then it requires:
- `game` (which loads `world`, systems, and components as needed)

This keeps tests and LÖVE consistent.

## Architectural Guidance
- Prefer pure logic systems (no `love.*`) for simulation/state; they are easy to unit test.
- Use effect systems for rendering/audio/input that call `love.*`.
- Optionally stub `love` in tests using `spec/support/love_stub.lua`.
- Keep components as plain tables (e.g., `pos`, `vel`, `sprite`).
- System order is gameplay-dependent; define it deliberately in `world.lua`.

## Examples (Generic)
- Logic systems: filters via `tiny.requireAll/Any`, updates component data.
- Effect systems: render via `love.graphics.*`, play sounds via `love.audio.*`, read input via `love.keyboard.*`.

## Version Notes
- LÖVE uses LuaJIT (Lua 5.1 semantics). The local toolchain here is Lua 5.4.
- Keep logic 5.1-compatible (avoid 5.3+ only features) to match LÖVE behavior.
- If strict parity is needed, we can add a LuaJIT env with hererocks and point busted to it.

## Limitations
- LÖVE doesn’t truly run headless here; graphical tests are not exercised by busted.
- Specs focus on logic; rendering/audio/input behavior is best validated in-game or with simple stubs.
- Paths assume tiny-ecs is vendored under `libs/` (e.g., `libs/tiny.lua` or `libs/tiny-ecs/tiny.lua`). Adjust loader paths if different.

## Testing Patterns and Observations
- tiny-ecs queueing: `world:add(entity)` takes effect next manage cycle.
  - In specs, tick once more with `world:update(0)` after updates that schedule adds/removes.
- Effect-system isolation: provide injectable dependencies (e.g., size providers) to avoid stubbing `love`.
- Reporter hint: for clearer failures, `-o gtest` can be used (e.g., `.lua/bin/busted -v -o gtest path/to/spec.lua`).
- Pure logic first: prefer testing systems that avoid `love.*`; stub only when necessary.

## Tuning and Hooks (General)
- Systems can accept options (e.g., margins, limits) to decouple them from LÖVE and improve testability.
- Input systems typically normalize direction vectors and scale by per-entity speed.
- Determinism: seed RNG in `love.load()` if reproducibility is needed.

## Troubleshooting
- Error: `module 'tiny' not found`
  - Ensure tiny-ecs exists in `libs/` (or `libs/tiny-ecs/`).
  - Confirm `main.lua` path setup matches your layout.
- Error starting tests: `LuaCov not found`
  - Installed `luacov` already. If removed, run: `.lua/bin/luarocks install luacov`.
- Error unpacking rocks: unzip missing
  - System `unzip` is configured in LuaRocks. If moved, edit `.lua/etc/luarocks/config-5.4.lua` `variables.UNZIP`.

## Handy Commands
- Run tests verbosely: `.lua/bin/busted -c -v`
- Run only matching specs: `.lua/bin/busted -c --pattern=_spec.lua --filter='move'`
- Print LuaRocks tree: `.lua/bin/luarocks list`
- Show busted version: `.lua/bin/busted --version`

## Next Steps (Optional)
- Add more systems (collision, input, animation) with pure logic where possible.
- Split draw/audio systems to isolate `love.*` calls.
- Consider a second world or priorities to control update/draw ordering.
