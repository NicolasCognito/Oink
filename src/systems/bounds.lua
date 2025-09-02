package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local tiny = require('tiny')

return function(margin)
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('pos')
  sys.margin = margin or 0

  function sys:process(e, dt)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local r = e.radius or 0
    local minx, miny = (self.margin + r), (self.margin + r)
    local maxx, maxy = (w - self.margin - r), (h - self.margin - r)
    if e.pos.x < minx then e.pos.x = minx end
    if e.pos.x > maxx then e.pos.x = maxx end
    if e.pos.y < miny then e.pos.y = miny end
    if e.pos.y > maxy then e.pos.y = maxy end
  end

  return sys
end

