package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('zone', 'rect')

  function sys:preProcess(dt)
    -- Gather agents (entities marked as agent)
    self._agents = {}
    local idx = 1
    for i = 1, #self.world.entities do
      local e = self.world.entities[i]
      if e and e.agent and e.pos then
        self._agents[idx] = e; idx = idx + 1
      end
    end
  end

  function sys:process(zone, dt)
    -- Always tick zones every frame; zone decides what to do
    if zone.on_update then zone.on_update(zone, self.world, self._agents) end
    if zone.on_tick then zone.on_tick(zone, self.world, self._agents) end
  end

  return sys
end
