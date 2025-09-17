# Dev Cheatsheet (LÖVE + tiny-ecs + busted)

This project skeleton supports building LÖVE games with tiny-ecs and testing game logic headlessly with busted. The notes below are framework-agnostic so you can plug in any game idea without changing the tooling.

## What’s Set Up
- Local Lua toolchain under `./.lua` (via hererocks) with Lua 5.4, LuaRocks, busted, and luacov.
- tiny-ecs vendored in `libs/` for entities/systems/world management.
- A conventional split into `game/world/components/systems` modules.
- Tests run outside LÖVE; only effect systems (e.g., input, draw) need `love.*`.

## Project Layout (Generic)
- `main.lua`: LÖVE entry. Extends require paths and delegates to `src/game.lua`.
- `src/game.lua`: High-level game lifecycle (`Game.load/update/draw`).
- `src/world.lua`: Creates the tiny-ecs world and registers systems in a deliberate order.
- `src/components/`: Component factories (plain data tables).
- `src/systems/`: Systems. Prefer pure logic; keep `love.*` calls in dedicated effect systems.
- `libs/`: Vendored libraries (e.g., `libs/tiny.lua`).
- `spec/`: Busted tests (optionally use `spec/support/love_stub.lua` to stub LÖVE).
- `.busted`: Busted config pointing to the local Lua and search paths.

## Running
- Run game: `love .`
- Run tests: `.lua/bin/busted -c`
- Run tests with gtest reporter: `.lua/bin/busted -c -v -o gtest`
- Wrapper: `bash scripts/test [--out scripts/test-results.txt] [--gtest] [spec/filter]`
  - Writes results to `scripts/test-results.txt` by default.
  - Forwards extra args to busted (e.g., `spec/my_system_spec.lua`).
  - Make targets: `make test`, `make test-gtest`, `make spec FILE=spec/xyz_spec.lua`.

## Module Resolution
`main.lua` configures require paths at `love.load()` to include:
- `src/?.lua; src/?/init.lua`
- `libs/?.lua; libs/?/init.lua`
- `libs/tiny-ecs/?.lua; libs/tiny-ecs/?/init.lua`

Then it requires `game`, which sets up the world and systems. This keeps runtime and tests aligned.

## Architectural Guidance
- Prefer pure logic systems (no `love.*`) for core simulation; they are easy to unit test.
- Isolate rendering/audio/input in effect systems that call `love.*`.
- Keep components as plain tables (e.g., `pos`, `vel`, `sprite`).
- Be explicit about system order in `world.lua` based on your game loop needs.
- If you introduce shared per-frame data, centralize it in a context module/system so it’s consistent across systems and specs.

## ECS Rules & Best Practices
- Stateless systems: do not keep mutable state across frames. Persist state on entities/components; use locals only within a tick.
- Pure updates: systems map input components to output components. Side effects are limited to component changes or emitting events.
- No cross-system coupling: systems should not call into other systems. Communicate via components or explicit queues/events.
- Components are data: no methods, no closures, no references to `world`, systems, or `love`; keep them serializable.
- Granularity: prefer small, orthogonal components; use tag components for boolean traits.
- Determinism: avoid order-dependent logic. If order matters, document it and encode phases explicitly.
- Entity lifecycle: don’t remove entities during iteration. Mark for destruction and let a dedicated system remove them at frame end.
- Membership changes: when adding/removing components, ensure the ECS refreshes filters. In specs, `world:update(0)` flushes queues.
- Queries: keep filters targeted (e.g., `tiny.requireAll`). Avoid full-world scans; precompute indices in a dedicated system if needed.
- Events/messages: prefer append-only queues that a consumer drains once per frame; avoid synchronous callbacks across systems.
- Input/IO isolation: keep rendering, audio, input, and file/network IO out of logic systems; inject data instead.
- Time handling: drive all time-based logic from `dt` provided to systems; don’t read global clocks inside systems.
- Randomness: inject RNG or seed globally; don’t call `math.random` ad hoc in hot loops without control.
- Performance: minimize allocations in hot paths; reuse tables; avoid building temporary objects per entity per frame.
- Testing: unit-test systems with minimal worlds and deterministic inputs; assert only on component state, not rendering.

## Testing Patterns
- tiny-ecs queueing: `world:add(entity)` and membership changes take effect on manage cycles.
  - In specs, tick once more with `world:update(0)` after scheduling adds/removes to flush queues.
- Favor pure logic in tests; stub or inject dependencies for effect systems to avoid coupling to LÖVE.
- Reporter hint: `-o gtest` gives structured diffs and clearer failures.

## Version Notes
- LÖVE runs LuaJIT (Lua 5.1 semantics); the local toolchain is Lua 5.4.
- Keep game logic 5.1-compatible to match LÖVE behavior.
- If you need strict parity, you can set up a LuaJIT hererocks tree and point busted to it.

## Limitations
- LÖVE itself is not exercised by specs; graphical/audio/input behavior is best validated in-game or with targeted stubs.
- Paths assume tiny-ecs is available under `libs/` (e.g., `libs/tiny.lua`); adjust if your layout differs.

## Tuning and Hooks
- Make systems configurable via constructor options to decouple from LÖVE and improve testability.
- Normalize and clamp inputs in input systems; scale by per-entity attributes where appropriate.
- For determinism, seed RNG in `love.load()` (e.g., `math.randomseed(...)`).
- For spawn/destroy workflows, consider using explicit queues and a dedicated system to flush them at frame end.

## Behavior Trees (tiny-bt & tiny-bt-tasks)
### Default
- Overview: `libs/tiny-bt.lua` provides compact behavior trees that integrate with tiny-ecs. Trees are shared assets; each entity holds a small runtime instance.
- Require: `local bt = require('tiny-bt'); local T = bt.dsl`.
- Build tree: `local tree = bt.build(T.selector{ T.sequence{ T.condition{name='HasTarget'}, T.action{name='Chase', params={max_speed=120}} }, T.action{name='Idle'} })`.
- Register leaves:
  - Condition: `bt.register_condition('HasTarget', function(ctx) return ctx.entity.target ~= nil end)`.
  - Action: `bt.register_action('Chase', { start=function(ctx) /* init */ end, tick=function(ctx, dt) return bt.RUNNING end, abort=function(ctx) /* cleanup */ end, validate=function(ctx) return true end })`.
- Attach to entity: `e.bt = bt.instance(tree, { tick_interval=0.05, stagger=true, name='EnemyAI' })`.
- Add system once: `world:add(bt.system{ interval=nil })` (or set `interval` for global throttling).
- Context fields: `ctx.world`, `ctx.entity`, `ctx.bb` (blackboard with `get/set/has`), `ctx.tree`, `ctx.node`, `ctx.params`, `ctx.state` (per-action memory table).
- Decorators: `inverter`, `succeeder`, `failer`, `repeat_n(n)`, `until_success`, `until_failure`, `wait(seconds)`, `cooldown(seconds)`, `time_limit(seconds)`; parallel with thresholds: `T.parallel{...}, {success=n, failure=n}`.
- Status values: `bt.SUCCESS`, `bt.FAILURE`, `bt.RUNNING`.
- Testing: drive a tiny world with only `bt.system` and a test entity; assert on component changes or `bt.last_status(e)`; use `bt.dump_status(e)` for debugging.
- Practices: keep actions/conditions pure; store any persistent data in `ctx.state` or entity components; avoid global singletons; prefer injected params via node `params`.
### Tasks
- Overview: `libs/tiny-bt-tasks.lua` is a task-based variant where leaves spawn short-lived ECS entities to do work. The BT returns RUNNING until the task entity signals completion.
- Require: `local bt = require('tiny-bt-tasks'); local T = bt.dsl`.
- Register task: `bt.register_task(name, { validate?(owner, params)->bool, spawn(owner, world, params)->task_entity })`.
  - Your systems process these task entities and must set `task_complete=true` and `task_result=bt.SUCCESS|bt.FAILURE`; honor `task_cancelled` on aborts.
- Build tree: use `T.task('name', params)` leaves alongside the same composites/decorators as default BTs.
- Add systems: `world:add(bt.system())` plus your task systems (e.g., a MoveTaskSystem). An example `bt.move_task_system()` is included for reference.
- Minimal example:
  - Condition: `bt.register_condition('enemy_visible', function(owner) return owner.senses and owner.senses.enemy end)`
  - Task: `bt.register_task('move_to', { spawn=function(owner, world, p) local e={bt_task=true, task_type='move', owner=owner, target=p, speed=p.speed or 5}; world:addEntity(e); return e end })`
  - Tree: `local tree = bt.build(T.sequence({ T.condition('enemy_visible'), T.task('move_to', {x=4,y=2,speed=8}) }))`
  - Wire: `agent.bt = bt.instance(tree, {tick_interval=0.05}); world:add(bt.system()); world:add(bt.move_task_system())`
- Decorators: inverter, succeeder, failer, repeat_n, until_success, until_failure, wait(s), cooldown(s), time_limit(s). Status: `bt.SUCCESS|bt.FAILURE|bt.RUNNING`.
- Testing: run a tiny world with `bt.system()` and only the systems your tasks need; assert on entity components or `task_result` side effects.

### Inline (Data‑Driven) Tasks & Conditions

- Inline tasks: You can pass a table directly to `T.task({...})`. The BT spawns a task entity by shallow‑copying this table and tagging it with `bt_task`, `bt_owner`, `bt_node`.
  - Example: `T.task({ task_type='move_to', move_to=true, target='owner.target.pos', speed='owner.speed', radius=8 })`
  - Systems pick these up by narrow filters (e.g., `tiny.requireAll('bt_task','move_to')`). The “logic” lives entirely in systems.

- Inline conditions: You can pass a table to `T.condition({...})` and provide a project‑level evaluator: `world:add(bt.system{ condition_eval=function(world, owner, data) ... end })`.
  - Keep the library generic; interpret condition data in your own evaluator, or prefer short “check tasks” that complete immediately.

- Shallow copy: Inline task payloads are shallow‑copied. Do not mutate nested tables captured from tree assets at runtime.

### Find Pattern (Query + Score)

- Pattern: Emit a long‑running `find` task that updates an owner field every frame based on a query and a score.
  - Task payload: `{ task_type='find', find=true, store='owner.target', claim=true, query=function(world, owner) return {...} end, score=function(owner, e) return number end }`
  - System behavior: `query` returns candidates; `score` ranks them (lower is better). The system writes the best to `store` and, when `claim=true`, sets `candidate.claimed_by = owner` (releasing any previous claim).
  - Continuous: The task usually does not complete; it re‑evaluates every frame.

### Parameter Resolution Convention

- To avoid rewiring systems, task params can come from:
  - Literal (number/table/entity)
  - Function `fn(owner, task, world) -> value`
  - Path string `'owner.target.pos'` or array `{'owner','target','pos'}`
  - Descriptor `{ from='owner'|'task'|'world', path='collector.speed', default=... }` or `{ eval=function(...) return ... end }`

- Precedence per param: descriptor → function → path → literal → system fallback paths → default.

- Example (move_to system):
  - `target`: fallback `'owner.target.pos'`; accepts `{x,y}`, entity with `.pos`, or function.
  - `speed`: fallbacks `'owner.speed'`, `'owner.collector.speed'`; default to config base speed.
  - `radius`: default to config pickup radius.

### Performance Tips

- Throttle: use `bt.instance(tree, { tick_interval=0.05 })` per entity or `bt.system{ interval=0.05 }` globally.
- Minimize allocations: reuse buffers in hot tasks (e.g., `find`) or make `query` fill a task‑local table.
- Keep lambdas “pure”: compute values only; leave state mutations to systems.

### Editor's note
- Before using always consult the relevant guides in docs: `docs/TINY_BT_GUIDE.md` and `docs/TINY_BT_TASKS_GUIDE.md`.
- Use Tasks version by default; it provides clearer debugging and decouples long-running work via ECS.

## FSMs
- Overview: `libs/tiny-fsm.lua` implements simple finite state machines for mechanical/ambient logic (doors, traps, buildings, UI). Do not use for agent AI; prefer BTs there.
- Require: `local fsm = require('tiny-fsm')`.
- Register: `fsm.register_action('Name', { enter?, update?, exit? })`; `fsm.register_condition('Name', function(ctx) return true end)`.
- Build machine: `local M = fsm.build({ initial='idle', states={ idle={ transitions={{if_='Cond', to='work', priority=10, interrupt=true}} }, work={ on_update=function(ctx, dt) if done then return 'idle' end end } } })`.
- Attach + system: `e.fsm = fsm.instance(M, {tick_interval=0.05, stagger=true}); world:add(fsm.system())`.
- Context (`ctx`) fields in actions/conditions: `world`, `entity`, `state_name`, `params` (from transition), `next_event` (from queue). Helper: `fsm.call('CondName', ctx)` calls a registered condition by name.
- Transition semantics: interrupt transitions check first each tick, then `on_update` (may return a state name), then normal transitions (by descending `priority`).
- External control: `fsm.set(e, 'state')` to force a switch; `fsm.push_event(e, name, data)` and `fsm.pop_event(e)` for small, per-entity event queues.
- Scheduling: per-entity `tick_interval` or global `fsm.system{interval=...}`; seed `math.random` if you use `stagger=true` and need repeatability.
- Testing: build a tiny world with only `fsm.system()`, tick with fixed `dt`, assert on `fsm.state(e)` and component effects.

## Troubleshooting
- Error: `module 'tiny' not found`
  - Ensure tiny-ecs exists in `libs/` (or `libs/tiny-ecs/`).
  - Confirm `main.lua` path setup matches your layout.
- Error starting tests: `LuaCov not found`
  - Install with: `.lua/bin/luarocks install luacov`.
- Error unpacking rocks: unzip missing
  - Update `.lua/etc/luarocks/config-5.4.lua` `variables.UNZIP` or install `unzip`.
- Busted output unclear
  - Re-run with: `.lua/bin/busted -c -v -o gtest [path/to/spec.lua]`.

## Handy Commands
- Run tests verbosely: `.lua/bin/busted -c -v`
- Filter specs: `.lua/bin/busted -c --pattern=_spec.lua --filter='name'`
- List rocks: `.lua/bin/luarocks list`
- Show busted version: `.lua/bin/busted --version`
