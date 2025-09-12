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
  sys.filter = tiny.requireAll('collectable')

  function sys:process(e, dt)
    timestep.scaled_process(e, dt, function(entity, step_dt)
      -- per-item tick callback support
      if entity.on_collectable_tick then
        entity.on_collectable_tick(entity, step_dt, self.world)
      end
    end)
  end

  return sys
end
