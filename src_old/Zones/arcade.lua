local Pong = require('minigames.pong')

local function new_arcade(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'arcade',
    rect = { x = x or 0, y = y or 0, w = w or 64, h = h or 40 },
    label = opts.label or 'Arcade (G: Pong, Esc: close)',
    drawable = true,
    input_priority = opts.input_priority or 5,
    _active = false,
    _pong = nil,
  }

  local function find_minigame(world)
    if not world or not world.systems then return nil end
    for i = 1, #world.systems do
      local s = world.systems[i]
      if s and s.kind == 'minigame' then return s end
    end
    return nil
  end

  function z:on_input(input, ctx)
    if not input then return end
    if input.pressed('g') then
      self._active = not self._active
      local mg = find_minigame(ctx and ctx.world)
      if self._active then
        if mg then
          -- open returns the game instance; keep it so we can set controls
          self._pong = mg:open('pong', self, { w = 200, h = 140 })
        else
          self._active = false
        end
      else
        if mg then mg:close(self) end
        self._pong = nil
      end
    end
    if self._active and input.pressed('escape') then
      self._active = false
      local mg = find_minigame(ctx and ctx.world)
      if mg then mg:close(self) end
      self._pong = nil
    end
    -- Controls are handled inside the minigame (Pong polls love.keyboard)
  end

  function z:on_tick(ctx, dt)
    -- no-op; minigame system updates and draws
  end

  function z:draw(gfx, ctx)
    -- Hint text near the zone
    if gfx and gfx.print and (not self._active) then
      gfx.setColor(1,1,1,1)
      gfx.print('G: Play Pong', self.rect.x + 2, self.rect.y + self.rect.h + 2)
    end
  end

  return z
end

return { new = new_arcade }
