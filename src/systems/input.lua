package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local tiny = require('tiny')

return function()
  local sys = tiny.system()
  sys.filter = tiny.requireAll('vel', 'controllable')

  function sys:update(dt)
    local up    = love.keyboard.isDown('w') or love.keyboard.isDown('up')
    local down  = love.keyboard.isDown('s') or love.keyboard.isDown('down')
    local left  = love.keyboard.isDown('a') or love.keyboard.isDown('left')
    local right = love.keyboard.isDown('d') or love.keyboard.isDown('right')

    local ax = (right and 1 or 0) - (left and 1 or 0)
    local ay = (down and 1 or 0) - (up and 1 or 0)

    local mag = math.sqrt(ax*ax + ay*ay)
    for _, e in ipairs(self.entities) do
      local speed = e.speed or 120
      if mag > 0 then
        e.vel.x = (ax / mag) * speed
        e.vel.y = (ay / mag) * speed
      else
        e.vel.x = 0
        e.vel.y = 0
      end
    end
  end

  return sys
end

