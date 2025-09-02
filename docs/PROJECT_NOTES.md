# Project Notes (Current Demo)

This file tracks project-specific decisions for the current playable demo. Keep `DEV_CHEATSHEET.md` focused on general practices.

## Current Behavior
- Controls: WASD or arrow keys move the player (input system).
- Movement: `pos += vel * dt` (move system), velocity set by input and `e.speed`.
- Bounds: Player clamped to the window area (bounds system).
- Spawning: Coins spawn periodically at random positions within screen margins (spawner system).
- Drawing: Simple circle rendering and a small HUD label (draw helper).

## System Order (World)
- spawner → input → move → bounds
- Draw is invoked from `Game.draw()` (not a tiny-ecs system).

## Components
- Player: `{ pos, vel, speed, radius, drawable=true, controllable=true, label }`
- Coin: `{ pos, radius=4, color={1,0.85,0.1,1}, drawable=true, coin=true }`

## Tuning Hooks
- Spawner: `interval` (seconds), `margin` (px), `max_per_tick` (default 1). Determinism via `math.randomseed(...)`.
- Bounds: margin set in `world.lua`.
- Player speed: `components.player.new({ speed = ... })`.

## Testing Notes
- tiny-ecs queues adds/removes; after crossing a spawn interval, tick `world:update(0)` to apply changes in specs.
- Spawner accepts `get_size` to avoid stubbing `love.graphics.getWidth/Height` in tests.

