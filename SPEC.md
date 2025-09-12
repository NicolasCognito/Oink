# Oink Prototype Specification

## 1. Overview
- Purpose: Playable LÖVE2D prototype demonstrating an ECS-based simulation featuring agents, zones, inventories, time manipulation, and a minigame overlay.
- Core Concepts: tiny-ecs world, per-frame context snapshots, declarative FSMs, slot-based inventory, generic collection systems, composite zone colliders, probabilistic time scaling, handler-based input/draw.
- Deliverables: Running demo (`love .`), headless test suite (busted), internal docs/guides, reusable libraries and utilities.

## 2. Runtime & Tooling
- Engine: LÖVE2D (LuaJIT / Lua 5.1 semantics at runtime).
- Tests: Lua 5.4 with busted via hererocks toolchain. Headless `love` stub for specs under `spec/support/love_stub.lua`.
- ECS: Vendored tiny-ecs (`libs/tiny.lua`).
- Entry Point: `main.lua` sets require paths and delegates to `src/game.lua`.

## 3. Architecture
- World Composition (src/world.lua):
  - Systems order (update):
    1) `coin_spawner` 2) `context_provider` 3) `minigame` 4) `draw_ui` 5) `composer` 6) `input` 7) `zones`
    8) `zone_collect` 9) `agents` 10) `move` 11) `bounds` 12) `collectables` 13) `expiry` 14) `collect`
    15) `car_control` 16) `destroyer` 17) `spawner`.
  - Draw: `src/game.lua` calls `systems/draw.lua` and then draws overlay systems (`minigame`, `draw_ui`).
- Context System (src/systems/context_provider.lua): Builds per-frame snapshot (see 4).
- Composer System (src/systems/composer.lua): Attaches input and draw handlers idempotently based on entity components.

## 4. Context Snapshot
- Module: `src/systems/context_provider.lua` with `src/ctx.lua`.
- Snapshot fields:
  - `world`, `dt`.
  - `players` (list), `active_avatar` (controlled entity), `player` (compat alias).
  - `agents`, `collectables`, `zones`, `coins` (pre-filtered lists).
  - `active_zone`: highest-priority zone overlapped by the active avatar.
  - `active_zones`: all overlapped zones (composite collider aware).
  - `query(name|predicate)`: returns cached list by category/predicate.
- Active zone selection: composite containment via `collision.zone_any_contains_point` and `zone.input_priority`.

## 5. Input Pipeline
- System: `src/systems/input.lua`.
- InputState: `libs/input/helpers.lua` (held, pressed, released, repeatPressed; axes and normalize; `commit()`).
- Dispatch:
  - Actor handlers on the `active_avatar` (`who.input_handlers`).
  - Zone handlers for `active_zone` (`zone.input_handlers` and `zone.on_input`), or all overlapped as fallback when no clear winner.
- Global: `Tab` cycles avatar control (`libs/avatar.lua`).
- Handlers (attached by Composer):
  - `character`: WASD movement; uses live `who.speed`.
  - `vehicle`: throttle (W) and turn (A/D), friction, heading-based velocity.
  - `inventory`: `1..9` select slot; `Space` drop one from active slot.
  - `mount` (player only): `Enter` toggles `collectable={name='driver', persistent=true}`.

## 6. Draw Pipeline
- System: `src/systems/draw.lua`: gathers per-entity draw handlers and sorts by layers: `background` < `zones` < `world` < `overlay` < `ui`.
- Profiles: `libs/draw/profiles.lua` attaches zone outlines (rect + sub-colliders), generic entity circles, and wraps custom `e.draw`.
- UI: `src/systems/draw_ui.lua` with dev toggles:
  - F1: show active label; F2: inventory HUD (active avatar); F3: slot inspector.

## 7. Collision & Composite Zones
- Library: `libs/collision.lua`.
- Primitives: `rect_contains_point`, `rects_overlap`, `rect_center`, `circles_overlap` (tables only), `circle_contains_point`.
- Composite support:
  - `collider_contains_point(base_rect, collider, x, y)` for `rect`/`circle` colliders offset from base.
  - `zone_any_contains_point(zone, x, y, {filter})` checks base and `zone.colliders`.

## 8. Time Scaling
- Library: `libs/timestep.lua` (probabilistic sub-steps):
  - 0x: skip; <1x: update with probability = scale; >=1x: `floor(scale)` steps plus fractional probabilistic step.
  - Combined scale: `entity.time_scale * entity._time_scale_vortex`.
- Systems honoring scaling: `move`, `agents`, `collectables`, `expiry`, `zones`.

## 9. Agents & FSMs
- Base Agent: `src/components/agent.lua` with `{ agent, pos, vel, speed, radius, drawable? }`.
- FSM runner: `libs/fsm.lua` with `ensure(entity, def)` and `step(entity, ctx, dt)`.
- Multi-FSM host: `libs/fsm_multi.lua` (e.g., citizen composer + hunger/vacation sub-FSMs).
- FSMs:
  - Zombie (`src/FSMs/zombie.lua`): idle/chase nearest player.
  - Miner (`src/FSMs/miner.lua`): seek `mine` zone center; work while inside.
  - Token Miner (`src/FSMs/token_miner.lua`): seek `token_mine`, drop work tokens while working.
  - Tax Collector (`src/FSMs/tax_collector.lua`): swarm-coordinated coin seeking, vault selection, deposit.
  - Citizen (`src/FSMs/citizen.lua`): working ⇄ going_home/sleeping ⇄ vacation based on fatigue; composes `work_def` FSM and hunger FSM.
  - Hunger (`src/FSMs/hunger.lua`): normal/hungry states; in hungry, accept only food and consume from inventory, slower speed.
  - Vacationer (`src/FSMs/vacationer.lua`): slow wander and reduce fatigue.

## 10. Components
- Player (`src/components/player.lua`): `controllable`, `collector`, `player`, `driver`, inventory with reserved/defined slots:
  - Slot 1 reserved for `coin`.
  - Slot 2 defined for `passenger` (accepts `agent` entities).
  - Collect policy: `collect_query` matches any collectable; self-protection handled in Collect system.
- Others: `zombie`, `miner`, `token_miner`, `tax_collector`, `citizen`, `chicken`, `car` (with driver slot), and collectables `coin`, `egg`, `ruby`, `work_token`.

## 11. Inventory Semantics
- Module: `libs/inventory.lua`.
- Structure: `{ cap, slots (sparse), items (map), items_value (map), count, value }`.
- Slot APIs:
  - `reserve_slot(inv, idx, name, opts)`: permanent slot with reserved name; retains label at count=0; optional `accept`/`stack`.
  - `define_slot(inv, idx, opts)`: permanent slot without reserved-name semantics; `default_name`, `accept`, `stack`.
- Adding:
  - `add(inv, name, value)`: stack into same-name slot if acceptable; else into first acceptable reserved slot; else new slot at first hole.
  - `add_entity(inv, entity)`: persistent entity reference into acceptable reserved slot or new dedicated slot.
- Removing:
  - `remove_one(inv, idx)`: returns `{ name, value }` or `{ entity, persistent }`; resets reserved/defined slot name to `default_name` when emptied.
- Transfer:
  - `transfer_all(from, to)` and `transfer(from, to, { names, max_count })` maintain sparse slots and per-name counts/values.
- Capacity: `isFull(inv)` compares `count >= cap`.
- UX: indices are stable; empty slots remain (holes) for muscle memory.

## 12. Collection Systems
- Collect (`src/systems/collect.lua`):
  - Processes all `collectable` entities; gathers collectors (`collector + pos + inventory`).
  - Honors collector `collect_query` membership sets first, then `accept_collectable` predicate.
  - Self-protection: never collect itself; circle-radius overlap check.
  - Persistent pickup uses `add_entity` and removes item from world; records use `add`.
  - Drop cooldown: respects and decrements `item.just_dropped_cd`.
- Zone Collect (`src/systems/zone_collect.lua`):
  - Rectangular `collector` zones with `inventory` absorb items inside their rect.
  - Uses `zone.collect_query(zone, snapshot)` if present (preferred) or `zone.accept_collectable` predicate.

## 13. Zones Catalog
- Vault (`src/Zones/vault.lua`): endless inventory; absorbs only coins (via `entity_match` policy query and `accept_collectable`).
- Time Distortion (`src/Zones/time_distortion.lua`): velocity scaling applied inside for that frame; no persistent state.
- Time Vortex (`src/Zones/time_vortex.lua`): sets `_time_scale_vortex` for agents/items/zones inside; supports `modes` with Q/E rotation; `on_mode_change` applies immediately.
- Teleport (`src/Zones/teleport.lua`): composite colliders; left circle teleports to `(tx, ty)`, right panel toggles enabled via `P`, arrow keys adjust destination; draws crosshair overlay while on panel.
- Mine (`src/Zones/mine.lua`): spawns `ruby` near working miners at `production_interval`.
- Token Mine (`src/Zones/token_mine.lua`): absorbs `work` tokens; converts `work → ruby` and occasionally drops rubies.
- Shop (`src/Zones/shop.lua`): absorbs `ruby`/`egg`; converts to coin entities at 1:1 item count; drops coins near center.
- Main Hall (`src/Zones/main_hall.lua`): `modes=[Spawn,Buff]` actions consuming coins from a Vault (spawn collector; buff collectors’ speed +30%).
- Home (`src/Zones/home.lua`): passive; citizen sleeping restores fatigue faster (with optional `sleep_rate_bonus`).
- Bear Trap (`src/Zones/bear_trap.lua`): kills first agent entering and deactivates.
- Empty Area (`src/Zones/empty_area.lua`): build-from-template zone; `Q/E` rotate templates, `B` build; legacy single-key transforms M/T/V/H.
- Arcade (`src/Zones/arcade.lua`): toggles Pong minigame with `G`; `Esc` closes via host system.

## 14. Minigame Host
- System: `src/systems/minigame.lua`.
- Behavior:
  - Hosts one active minigame overlay; disables input system while active; `Esc` closes.
  - Bridge pattern for explicit communication:
    - To minigame: `params.bridge = { owner, close(), send(event, payload) }`.
    - On opener: `entity.minigame = { name, game, system, is_active(), close(), send(event,payload) }`.
- Example minigame: `minigames/pong.lua` (self-polled controls; renders to its own Canvas).

## 15. Movement, Bounds, Spawning, Destroy
- Move (`src/systems/move.lua`): `pos += vel * dt`, under time scaling.
- Bounds (`src/systems/bounds.lua`): clamps all entities with `pos` to window area (with margin).
- Spawning (`libs/spawn.lua` + `src/systems/spawner.lua`): queue-driven entity spawning at end of frame.
- Coin Spawner (`src/systems/coin_spawner.lua`): periodic coin spawn within margins; configurable interval and size provider.
- Destroyer (`src/systems/destroyer.lua`): removes entities with `marked_for_destruction=true`.

## 16. Policies & Matching
- Library: `libs/entity_match.lua`:
  - `match_policy(collector, item, ctx, policy)`: supports function entries and structured `{ all_of, any_of, none_of, where }` with blacklist/whitelist.
  - `build_query(policy)`: returns a function `(collector, ctx) -> items[]` used by collectors/zones for pre-filtering.

## 17. Avatar Control
- Library: `libs/avatar.lua`:
  - `candidates(world)`: controllable entities with `pos`/`vel`.
  - `get(world)`, `set(world, entity)`, `next(world, dir)` for control cycling.

## 18. Controls Summary
- Movement: `WASD` (characters), `W` throttle + `A/D` turn (vehicles).
- Avatar: `Tab` cycles controlled entity.
- Inventory: `1..9` select slot; `Space` drop from active slot.
- Mount: `Enter` toggle player’s driver collectable.
- Zone modes: `Q/E` rotate while overlapping the zone.
- Teleport panel: `P` toggle enabled; Arrow keys adjust destination.
- UI: F1 (label), F2 (inventory HUD), F3 (slot inspector).
- Minigame: `G` open/close Pong; `Esc` closes active minigame.

## 19. Tests (Representative)
- Movement/bounds/avatar: velocity updates; control handoff and cycling.
- Vehicle: acceleration and turning affect heading and velocities.
- Inventory: caps, reserved slot accept, persistent labels, entity slots persist after removal, drop-on-vault goes into vault.
- Collect: dedicated collectors, self-protection, multi-collector coordination, zone collect with `collect_query`.
- Zones: vault absorption; shop conversion; mine production; token mine conversion/give; bear trap kill/deactivate; teleport agent/item; composite collider detection; empty area build; time distortion and vortex effects (agents/items/zones).
- FSMs: zombie chase thresholds; miner work; citizen sleep/vacation cycles; hunger collect-and-eat.
- Time scaling: expiry determinism, egg production under vortex, zones tick rate under vortex.

## 20. Known Limitations
- `collision.circles_overlap` only supports table `{x,y}` signature.
- Teleport zone: no cooldown/nudging safeguards; possible ping-pong if destination inside another teleport.
- Deprecated AI systems kept under `src/systems/deprecated/` (not used by demo).
- No camera/viewport; draw operates in screen space (see `docs/rendering-roadmap.md`).
- No persistence/save, no spatial indexing (acceptable for demo scale).

## 21. Extensibility
- Add FSMs under `src/FSMs/` and attach via `entity.brain.fsm_def`.
- New zones: implement `new(...)`, `on_tick(zone, ctx, dt)`, optional `on_input`, `modes` + `on_mode_change`.
- Time control: set `entity.time_scale` or zone-applied `._time_scale_vortex`.
- Inventory policies: use `entity_match.build_query` to declaratively scope collectables.

## 22. Repository Layout
- `main.lua`, `src/game.lua`, `src/world.lua`, `src/ctx.lua`.
- `src/systems/`: input, draw, draw_ui, composer, minigame, zones, zone_collect, agents, move, bounds, collectables, expiry, collect, car_control, spawner, destroyer (and deprecated/).
- `src/components/`: player, zombie, citizen, chicken, miner, token_miner, tax_collector, car, coin, egg, ruby, work_token.
- `src/FSMs/`: zombie, citizen, hunger, vacationer, miner, token_miner, tax_collector, chicken.
- `src/Zones/`: vault, time_distortion, time_vortex, teleport, mine, token_mine, shop, main_hall, home, bear_trap, empty_area, arcade.
- `libs/`: tiny-ecs, timestep, spawn, inventory, collision, avatar, entity_match; input handlers/profiles; ai helpers; draw profiles.
- `minigames/pong.lua`.
- `spec/`: comprehensive test suite; `spec/support/love_stub.lua`.
- `docs/`: guides and plans (time scaling, ECS FSMs, composite zones, minigame system, input/draw refactor, rendering roadmap, inventory rework, dev cheatsheet, project notes).
- `Makefile`, `scripts/test`, `.busted`.

## 23. Running & Testing
- Run game: `love .` (from repo root).
- Run tests: `make test` or `bash scripts/test` (writes `scripts/test-results.txt`).
  - Verbose/gtest: `make test-gtest` or `bash scripts/test --gtest`.
  - Single spec: `make spec FILE=spec/<name>_spec.lua`.

## 24. Acceptance Criteria (Prototype Scope)
- All systems operate solely through ECS (no component churn for state changes).
- Input/draw behavior composed via handlers; no hidden per-frame attachments.
- Context remains the single source of per-frame truth; input uses `active_avatar` and `active_zone` exclusively.
- Inventory preserves slot indices; reserved/defined semantics and accept policies validated by tests.
- Time scaling statistically correct and applied consistently across agents/items/zones.
- Minigame host blocks main input and overlays rendering; closes with `Esc`.
- Test suite passes consistently (headless).

## 25. Glossary
- ECS: Entity Component System.
- FSM: Finite State Machine.
- Collector: Entity or zone that can absorb `collectable`s into an `inventory`.
- Persistent Collectable: An item that should be carried as an entity reference (non-stacking), not as a stack record.
- Zone Modes: A zone’s discrete configurations rotated via Q/E (`zone.modes` array with active at index 1).

