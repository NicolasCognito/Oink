package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local fsm = require('fsm')
local ctx = require('ctx')
local timestep = require('timestep')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = function(self, e)
    return e.pos and e.vel and e.brain and e.brain.fsm_def
  end

  function sys:process(e, dt)
    fsm.ensure(e, e.brain.fsm_def)
    timestep.scaled_process(e, dt, function(entity, step_dt)
      local snapshot = ctx.get(self.world, step_dt)
      fsm.step(entity, snapshot, step_dt)
    end)
  end

  return sys
end
