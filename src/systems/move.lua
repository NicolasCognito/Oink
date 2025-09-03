package.path = table.concat({
  package.path,
  'libs/?.lua',
  'libs/?/init.lua',
  'libs/tiny-ecs/?.lua',
  'libs/tiny-ecs/?/init.lua',
}, ';')

local tiny = require('tiny')
local timestep = require('timestep')

return function()
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('pos', 'vel')
  function sys:process(e, dt)
    timestep.scaled_process(e, dt, function(entity, step_dt)
      entity.pos.x = entity.pos.x + entity.vel.x * step_dt
      entity.pos.y = entity.pos.y + entity.vel.y * step_dt
    end)
  end
  return sys
end
