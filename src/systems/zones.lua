package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local ctx = require('ctx')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('zone', 'rect')

  function sys:process(zone, dt)
    -- Always tick zones every frame; zone decides what to do using ctx
    local snapshot = ctx.get(self.world, dt)
    if zone.on_update then zone.on_update(zone, snapshot) end
    if zone.on_tick then zone.on_tick(zone, snapshot) end
  end

  return sys
end
