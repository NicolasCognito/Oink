package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local ctx = require('ctx')
local avatar = require('avatar')
local IH = require('input.helpers')
local collision = require('collision')
-- Profiles are attached by Composer, not per-frame here

return function()
  local sys = tiny.system()
  sys.kind = 'input'
  sys._prev = {}
  sys._active_zone = nil
  sys._sticky_zone = nil
  sys._zone_prev_winner = nil

  function sys:update(dt)
    local snapshot = ctx.get(self.world, dt)
    -- Build input snapshot
    local input = IH.build_state(self._prev)

    -- Actor target comes from Context
    local who = snapshot.active_avatar

    -- Global: avatar cycle on Tab repeat
    if input.repeatPressed('tab', 0.25, dt) then
      avatar.next(self.world, 1)
      -- refresh who in case it changed
      who = avatar.get(self.world)
    end

    -- Handlers are attached by Composer; no per-frame ensure here
    if who and who.input_handlers and #who.input_handlers > 0 then
      for i = 1, #who.input_handlers do
        local h = who.input_handlers[i]
        if h and h.on then h.on(h, who, snapshot, input, dt) end
      end
    end

    -- Use active zone computed by context provider only
    local active_zone = snapshot.active_zone or (snapshot.active_zones and snapshot.active_zones[1])

    local function run_zone(z)
      if not z then return end
      if z.input_handlers then
        for i = 1, #z.input_handlers do
          local h = z.input_handlers[i]
          if h and h.on then h.on(h, z, snapshot, input, dt) end
        end
      end
      if z.on_input then z.on_input(z, input, snapshot, dt) end
    end
    if active_zone then
      run_zone(active_zone)
    elseif snapshot.active_zones and #snapshot.active_zones > 0 then
      for i = 1, #snapshot.active_zones do run_zone(snapshot.active_zones[i]) end
    end

    -- Commit input edges
    input.commit()
  end

  return sys
end
