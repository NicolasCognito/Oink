# Minigame System Usage

This document explains how to embed self‑contained LÖVE canvas minigames into the project using the `Minigame` system, including the bridge pattern for safe, explicit communication.

## Overview
- The Minigame system hosts a single active minigame at a time and draws it above the regular pipeline.
- While a minigame is active, the input system is deactivated (game input is blocked). Only `Esc` is handled globally to close the minigame.
- Minigames are regular modules under `minigames/` that render into their own `Canvas` and poll their own controls (via `love.keyboard`).
- Communication back to the game is explicit via a small, bi‑directional bridge tied to the opener entity (e.g., a Zone).

## Files
- `src/systems/minigame.lua` — host system with `open/close/update/draw` API.
- `minigames/pong.lua` — reference minigame that renders into a canvas and polls `W/S` or `Up/Down`.
- `src/Zones/arcade.lua` — example Zone that opens/closes the Pong minigame on `G`/`Esc`.

## World Integration
1. Add system to the world before draw (already wired in `src/world.lua`):
   - `world:add(Minigame())`
2. Ensure the overlay draws last (already wired in `src/game.lua`):
   - After `Draw.draw(world)`, iterate systems and call `minigame:draw()`.

## Opening a Minigame
Typical opener (e.g., a Zone) toggles the minigame:

```
local function find_minigame(world)
  for i = 1, #world.systems do
    local s = world.systems[i]
    if s and s.kind == 'minigame' then return s end
  end
end

function z:on_input(input, ctx)
  if input.pressed('g') then
    local mg = find_minigame(ctx.world)
    if not self._active then
      -- Open returns the game instance
      local game = mg:open('pong', self, { w = 200, h = 140 })
      self._active, self._pong = true, game
    else
      mg:close(self)
      self._active, self._pong = false, nil
    end
  end
end
```

Notes:
- `open(spec, owner, params)` loads `minigames/spec.lua` and passes `params`.
- While active, the input system is temporarily disabled.
- Press `Esc` to close (handled by the Minigame system even while input is disabled).

## The Bridge (bi‑directional)
When opening, the system injects a small bridge into `params` and also attaches a relation to the opener entity:

- `params.bridge` (available inside the minigame):
  - `owner`: the opener entity
  - `close()`: close via the system
  - `send(event, payload)`: notify the opener (calls `owner.on_minigame_event(owner, system, event, payload)` if present)

- `owner.minigame` (available to the opener):
  - `name`: module name
  - `game`: the minigame instance
  - `system`: the host system
  - `is_active()`: whether the minigame is running
  - `close()`: request close
  - `send(event, payload)`: send an event into the minigame if it exposes `on_event`

This gives explicit, two‑way communication without exposing the entire World by default.

## Writing a Minigame Module
A minigame lives in `minigames/<name>.lua` and should expose a `new(w, h, opts)` constructor that returns an object with `update`, `render`, and `draw` methods.

Skeleton:
```
local M = {}

function M.new(w, h, opts)
  local lg = love.graphics
  local self = { w = w or 200, h = h or 140, canvas = nil, bridge = opts and opts.bridge }

  local function keydown(k)
    return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(k)
  end

  function self:update(dt)
    -- Poll controls locally, no coupling to main input system
    if keydown('w') or keydown('up') then -- move up end
    if keydown('s') or keydown('down') then -- move down end
    -- Optionally: signal state via bridge
    -- if self.bridge and self.bridge.send then self.bridge.send('tick') end
  end

  function self:render()
    if not self.canvas or self.canvas:getWidth() ~= self.w or self.canvas:getHeight() ~= self.h then
      self.canvas = lg.newCanvas(self.w, self.h)
    end
    lg.push('all')
    local prev = lg.getCanvas()
    lg.setCanvas(self.canvas)
    lg.clear(0.05, 0.05, 0.08, 1)
    -- draw contents here
    lg.setCanvas(prev)
    lg.pop()
  end

  function self:draw(gfx, x, y, scale)
    if not self.canvas then return end
    gfx.setColor(1,1,1,1)
    gfx.draw(self.canvas, x or 0, y or 0, 0, scale or 2, scale or 2)
  end

  -- Optional: receive events from opener
  -- function self:on_event(event, payload) end

  return self
end

return M
```

## Lifecycle
- `open()` → system disables Input system → minigame `update/render` each frame → overlay draws after main draw
- `Esc` pressed → system closes → system re‑enables Input system → control returns to the game

## Patterns for Game Influence
Keep minigames mostly isolated; prefer signaling intended effects:
- Owner mediation (recommended): zone listens in `on_minigame_event`, applies changes to the world.
- Narrow bridge API: expose just what is needed (e.g., `awardCoins(n)`, `spawn(e)`, `close()`).
- Avoid passing World/Avatar directly unless read‑only; mutations should occur via the owner/bridge.

# FAQ
- Why block input globally?
  - To ensure predictable focus and avoid gameplay side effects while a minigame is in the foreground. Only `Esc` is handled to close the overlay.
- Can we stack multiple minigames?
  - Current host supports a single active game. A simple stack could be added if needed.
- How do we test minigames?
  - Most logic can run headless; canvas rendering is only active when `love.graphics` exists. Keep tests minimal and verify integration in‑game.
