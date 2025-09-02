package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')

return function()
  local sys = tiny.system()
  function sys:update(dt)
    local entities = self.world.entities
    for i = 1, #entities do
      local e = entities[i]
      if e and e.marked_for_destruction then
        self.world:remove(e)
      end
    end
  end
  return sys
end

