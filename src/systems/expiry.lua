package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local timestep = require('timestep')

return function()
  local sys = tiny.processingSystem()
  -- Any entity with an expiry TTL is handled here
  sys.filter = function(self, e)
    return e.expire_ttl ~= nil
  end

  function sys:process(e, dt)
    timestep.scaled_process(e, dt, function(entity, step_dt)
      entity.expire_age = (entity.expire_age or 0) + (step_dt or 0)
      if entity.expire_age >= entity.expire_ttl then
        entity.marked_for_destruction = true
      end
    end)
  end

  return sys
end

