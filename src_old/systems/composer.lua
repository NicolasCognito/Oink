package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local InputProfiles = require('input.profiles')
local DrawProfiles = require('draw.profiles')

-- Composer: attaches input and draw handlers based on entity components.
-- Idempotent; only re-applies when a simple signature of relevant flags changes.
return function()
  local sys = tiny.system()

  local function signature(e)
    -- Capture relevant properties that affect profile attachment
    local parts = {
      e and e.controllable and 1 or 0,
      e and e.pos and 1 or 0,
      e and e.vel and 1 or 0,
      e and e.car and 1 or 0,
      e and e.inventory and 1 or 0,
      e and e.player and 1 or 0,
      e and e.zone and 1 or 0,
      e and e.rect and 1 or 0,
      e and e.drawable and 1 or 0,
      (type(e.draw) == 'function') and 1 or 0,
    }
    return table.concat(parts, ':')
  end

  function sys:update(dt)
    local world = self.world
    if not world or not world.entities then return end
    for i = 1, #world.entities do
      local e = world.entities[i]
      if e and not e.marked_for_destruction then
        local sig = signature(e)
        if e._compose_sig ~= sig then
          -- Attach or refresh profiles; ensure is idempotent
          InputProfiles.ensure(e)
          DrawProfiles.ensure(e)
          e._compose_sig = sig
        end
      end
    end
  end

  return sys
end

