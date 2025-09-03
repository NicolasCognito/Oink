package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local ctx = require('ctx')
local timestep = require('timestep')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('zone', 'rect')

  function sys:process(zone, dt)
    -- Always tick zones, but respect per-zone time scaling via probabilistic sub-steps.
    local snapshot = ctx.get(self.world, dt)
    timestep.scaled_process(zone, dt, function(_, step_dt)
      -- Pass step_dt explicitly as third argument; keep ctx unchanged.
      if zone.on_update then zone.on_update(zone, snapshot, step_dt) end
      if zone.on_tick then zone.on_tick(zone, snapshot, step_dt) end
    end)
  end

  return sys
end
