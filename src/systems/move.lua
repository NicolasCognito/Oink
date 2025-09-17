local tiny = require('tiny')

local function process(self, e, dt)
  local vx, vy = e.vel.x or 0, e.vel.y or 0
  if vx ~= 0 or vy ~= 0 then
    e.pos.x = e.pos.x + vx * dt
    e.pos.y = e.pos.y + vy * dt
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('pos', 'vel')
  System.name = 'MoveSystem'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end

