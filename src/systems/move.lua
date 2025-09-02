package.path = table.concat({
  package.path,
  'libs/?.lua',
  'libs/?/init.lua',
  'libs/tiny-ecs/?.lua',
  'libs/tiny-ecs/?/init.lua',
}, ';')

local tiny = require('tiny')

return function()
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('pos', 'vel')
  function sys:process(e, dt)
    e.pos.x = e.pos.x + e.vel.x * dt
    e.pos.y = e.pos.y + e.vel.y * dt
  end
  return sys
end
