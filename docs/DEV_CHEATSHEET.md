# Oink Dev Cheatsheet (LÖVE + tiny-ecs + busted)

This repo is set up to develop game logic with tiny-ecs, run the game in LÖVE, and test logic headlessly with busted.

## What’s Set Up
- Local Lua toolchain under `./.lua` (via hererocks) with Lua 5.4, LuaRocks, busted, and luacov.
- tiny-ecs vendored in `libs/` and used by systems/world.
- Game orchestration split into modules (game/world/components/systems).
- Tests run without LÖVE; only effect systems (e.g., input, draw) need `love.*`.

## Core Systems
- Context: builds a per-frame snapshot (`src/ctx.lua`) and shares it with systems. Provided by `systems/context_provider.lua`.
- Agents: single system that runs per-entity FSM “brains”. Each agent has `brain = { fsm_def = require('FSMs.<name>') }`; the system reads `ctx` and steps `libs/fsm.lua` for every agent.
- Zones: generic system that reads `ctx` and invokes zone callbacks; no zone-specific logic here.

## Project Layout
- `main.lua`: LÖVE entry. Sets require paths, delegates to `src/game.lua`.
- `src/game.lua`: Orchestrates world lifecycle (`Game.load/update/draw`).
- `src/world.lua`: Builds tiny-ecs world; registers systems.
- `src/ctx.lua`: Per-frame context module (`set/get` + lazy snapshot builder).
- `src/components/`: Component factories (plain data tables).
- `src/FSMs/`: Declarative FSMs for agents (e.g., `zombie.lua`, `tax_collector.lua`).
- `src/systems/`: Systems (prefer pure logic; effect systems may use `love.*`).
  - `context_provider.lua`: Produces `ctx` each frame.
  - `agents.lua`: Runs FSM brains with a per-frame context.
  - `zones.lua`: Calls zone callbacks with a per-frame context.
  - `zone_collect.lua`: Generic absorption of collectables by rectangular zones with `collector` + `inventory`.
  - `coin_spawner.lua`: Periodic coin spawning.
  - `spawner.lua`: Drains queued spawn requests.
  - `destroyer.lua`: Removes entities marked for destruction.
- `libs/`: Vendored libraries (tiny-ecs at `libs/tiny.lua`).
- `spec/`: Busted tests (`spec/support/love_stub.lua` available if needed).
- `.busted`: Configures search paths and uses `./.lua/bin/lua`.

## Running Things
- Run game: `love .` (from repo root).
- Run tests: `.lua/bin/busted -c` (uses `.busted` config and prints coverage if available).
- Run tests (gtest fallback): `.lua/bin/busted -c -v -o gtest` (use if failures are unclear or output is sparse).
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
 - Current order (runtime): `input → context → zones → zone_collect → agents → move → bounds → collect → destroyer → spawner`.
- Agents: attach behaviors via `brain.fsm_def`; keep stateful data on entities; use helpers.
- Zones: keep behavior in zone files; use system-provided `ctx` to query entities.
  - Common collection is handled by `zone_collect.lua` (rect contains collectables → inventory.add → remove item).

## Examples (Generic)
- Logic systems: filters via `tiny.requireAll/Any`, updates component data.
- Effect systems: render via `love.graphics.*`, play sounds via `love.audio.*`, read input via `love.keyboard.*`.
- Agents: define FSMs under `src/FSMs/` and reference them in components via `brain.fsm_def`.
- Zones: implement callbacks (`on_tick(zone, ctx)`, optional `on_update(zone, ctx)`) in `src/Zones/*`.
 - Context: access via `local C = require('ctx'); local snapshot = C.get(world, dt)`; context_provider sets it each frame.

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
- FSMs: test via `systems/agents` with a minimal world; attach `brain` to test entities and assert velocity/state changes.
- Zones: unit-test zone callbacks by constructing zones/entities and invoking the zones system; use `ctx` instead of scanning the world in zone code.

## Tuning and Hooks (General)
- Systems can accept options (e.g., margins, limits) to decouple them from LÖVE and improve testability.
- Input systems typically normalize direction vectors and scale by per-entity speed.
- Determinism: seed RNG in `love.load()` if reproducibility is needed.
- Inventory/Collectables: attach `inventory` to collectors and `collectable={name,value}` to items; keep caps in inventory.
- Context (`ctx`): zones system provides `{ world, dt, agents, collectables, zones, query(...) }` per frame for zone logic.
- Spawn/Destroy:
  - Spawn queue: `local spawn = require('spawn'); spawn.request(entity)`; `systems/spawner` drains it at end of frame.
  - Destroy: set `entity.marked_for_destruction = true`; `systems/destroyer` removes it at end of frame.

## Troubleshooting
- Error: `module 'tiny' not found`
  - Ensure tiny-ecs exists in `libs/` (or `libs/tiny-ecs/`).
  - Confirm `main.lua` path setup matches your layout.
- Error starting tests: `LuaCov not found`
  - Installed `luacov` already. If removed, run: `.lua/bin/luarocks install luacov`.
- Error unpacking rocks: unzip missing
  - System `unzip` is configured in LuaRocks. If moved, edit `.lua/etc/luarocks/config-5.4.lua` `variables.UNZIP`.
- Busted run fails silently or output is hard to read
  - Re-run with the gtest reporter for structured output and clearer diffs: `.lua/bin/busted -c -v -o gtest [path/to/spec.lua]`.

## Handy Commands
- Run tests verbosely: `.lua/bin/busted -c -v`
- Run only matching specs: `.lua/bin/busted -c --pattern=_spec.lua --filter='move'`
- Print LuaRocks tree: `.lua/bin/luarocks list`
- Show busted version: `.lua/bin/busted --version`

## Next Steps (Optional)
- Add more systems (collision, input, animation) with pure logic where possible.
- Split draw/audio systems to isolate `love.*` calls.
- Consider a second world or priorities to control update/draw ordering.
