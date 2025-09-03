# Project Notes (Current Demo)

This file tracks project-specific decisions for the current playable demo. Keep `DEV_CHEATSHEET.md` focused on general practices.

## Current Behavior
- Controls: WASD or arrow keys move the player (input system).
- Mode switch: While the player stands on a zone supporting it, press `Q`/`E` to cycle the zone mode.
- Movement: `pos += vel * dt` (move system), velocity set by input and `e.speed`.
- Bounds: Entities clamped to the window area (bounds system).
- Spawning: Coins spawn periodically at random positions within screen margins (spawner system).
- Drawing: Zones as rectangles (active red, inactive gray); entities as circles and a small HUD label.
- Agents: Unified agents system runs per-entity FSM brains for zombie and tax collector.
- Zones: Generic zones system calls zone callbacks each frame with a per-frame context.
 - Collectables: Items may run per-tick logic and expire via `systems/collectables`.

## System Order (World)
- input → context → zones → zone_collect → agents → move → bounds → collect → destroyer → spawner
- Draw is invoked from `Game.draw()` (not a tiny-ecs system) and renders zones first.

## Components
- Agent (base): `{ agent=true, pos, vel, speed, radius, drawable?, color?, label? }`
- Player: `Agent + controllable=true + collector=true + player=true + inventory`
- Tax Collector: `Agent + collector=true + inventory + brain.fsm_def = FSMs.tax_collector`
- Zombie: `Agent + zombie=true + aggro + brain.fsm_def = FSMs.zombie`
- Chicken: `Agent + chicken=true + brain.fsm_def = FSMs.chicken` (wanders; lays eggs periodically)
- Coin: `{ pos, radius=4, color={1,0.85,0.1,1}, drawable=true, coin=true, collectable={name='coin', value=1} }`
- Egg: `{ pos, radius=3, color=..., drawable=true, collectable={name='egg', value=1}, expire_ttl, expire_age }`
- Bear Trap Zone: `{ zone=true, type='bear_trap', active, rect={x,y,w,h}, drawable=true, on_tick=Zones.bear_trap.on_tick }`
- Time Distortion Zone: `{ zone=true, type='time_distortion', rect, factor, on_tick }` (slows agents inside; restores on exit)
- Main Hall Zone: `{ zone=true, type='main_hall', rect, modes=['spawn_collector','buff_collectors'], on_tick, on_mode_switch }`

## Tuning Hooks
- Spawner: `interval` (seconds), `margin` (px), `max_per_tick` (default 1). Determinism via `math.randomseed(...)`.
- Bounds: margin set in `world.lua`.
- Player/Agent speed: `components.*.new({ speed = ... })`.
- Inventory caps: `Inventory.new(cap)` for player/collector.
- Agent FSMs: adjust aggro/speed via entity fields or FSM ctx.
- Zones: implement `on_tick(zone, ctx)` to run logic each frame; use `ctx.agents/collectables/zones`.
- Context provider: `systems/context_provider.lua` sets `src/ctx.lua` per frame.
- Spawns/Destroy: request via `libs/spawn.lua` or set `marked_for_destruction` and let systems apply at frame end.
 - Chicken: `egg_interval`, `egg_ttl`, `wander_change`, `speed` on the chicken component.
 - Main Hall modes:
   - `spawn_collector`: costs 10 coins from Vault; spawns a new Tax Collector near the hall.
   - `buff_collectors`: costs 50 coins from Vault; increases Tax Collectors’ speed by 30%.
   - Mode switching via input `Q`/`E` while overlapping the zone.
- Zone collectors: tag zone with `collector=true`, give it `inventory`, and `zone_collect` will absorb coins or filters via `zone.accept_collectable`.

## Testing Notes
- tiny-ecs queues adds/removes; after crossing a spawn interval, tick `world:update(0)` to apply changes in specs.
- Spawner accepts `get_size` to avoid stubbing `love.graphics.getWidth/Height` in tests.
- Zones: after a zone removes an entity, call `world:update(0)` to finalize state; zone callbacks receive `ctx` rather than scanning the world.
