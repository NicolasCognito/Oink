local tiny = require('tiny')

local function process(self, e, dt)
  local override_active, override_speed
  -- scan for a globals entity; quick and fine for demo
  for _, ent in ipairs(self.world.entities) do
    if ent.globals then
      override_active = ent.override_speed_active
      override_speed = ent.override_speed
      break
    end
  end
  if override_active then
    e.collector.speed = override_speed or e.collector.base_speed
  else
    e.collector.speed = e.collector.base_speed
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('collector')
  System.name = 'CollectorSpeedSystem'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
