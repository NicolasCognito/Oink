package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local ctx = require('ctx')
local avatar = require('avatar')
local collision = require('collision')
local IH = require('input.helpers')
local H_character = require('input.handlers.character')
local H_inventory = require('input.handlers.inventory')
local H_mount = require('input.handlers.mount')

return function()
  local sys = tiny.system()
  -- fallback reusable handlers (used if entity has no input_handlers)
  sys._h_character = H_character({})
  sys._h_inventory = H_inventory({})
  sys._h_mount = H_mount({})
  sys._prev = {}
  sys._active_zone = nil
  sys._sticky_zone = nil
  sys._zone_prev_winner = nil

  function sys:update(dt)
    local snapshot = ctx.get(self.world, dt)
    -- Build input snapshot
    local input = IH.build_state(self._prev)

    -- Actor target = active avatar (fallback to first candidate to mirror previous behavior)
    local who = avatar.get(self.world)
    if not who then
      local list = avatar.candidates(self.world)
      if #list > 0 then who = avatar.set(self.world, list[1]) end
    end

    -- Global: avatar cycle on Tab repeat
    if input.repeatPressed('tab', 0.25, dt) then
      avatar.next(self.world, 1)
      -- refresh who in case it changed
      who = avatar.get(self.world)
    end

    -- Actor handlers: per-entity if available, else fallback to default trio
    if who then
      if who.input_handlers and #who.input_handlers > 0 then
        for i = 1, #who.input_handlers do
          local h = who.input_handlers[i]
          if h and h.on then h.on(h, who, snapshot, input, dt) end
        end
      else
        self._h_character.on(self._h_character, who, snapshot, input, dt)
        self._h_inventory.on(self._h_inventory, who, snapshot, input, dt)
        self._h_mount.on(self._h_mount, who, snapshot, input, dt)
      end
    end

    -- Determine active zone by priority among overlapped zones
    local active_zone = nil
    local px, py = who and who.pos and who.pos.x or nil, who and who.pos and who.pos.y or nil
    if px and py then
      local best_prio = nil
      for i = 1, #self.world.entities do
        local z = self.world.entities[i]
        if z and z.zone and z.rect then
          if collision.zone_any_contains_point(z, px, py) then
            local pr = tonumber(z.input_priority) or 0
            if (best_prio == nil) or (pr > best_prio) then
              best_prio = pr
              active_zone = z
            end
          end
        end
      end
    end

    -- Zone handlers on the single active zone
    if active_zone then
      -- If zone declares input handlers, let them process input (e.g., zone_mode module)
      if active_zone.input_handlers then
        for i = 1, #active_zone.input_handlers do
          local h = active_zone.input_handlers[i]
          if h and h.on then h.on(h, active_zone, snapshot, input, dt) end
        end
      end
      -- Zones may also implement on_input to consume arbitrary input directly
      if active_zone.on_input then
        active_zone.on_input(active_zone, input, snapshot, dt)
      end
    end

    -- Commit input edges
    input.commit()
  end

  return sys
end
