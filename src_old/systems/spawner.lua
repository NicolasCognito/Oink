package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local spawn = require('spawn')

return function()
  local sys = tiny.system()
  function sys:update(dt)
    local pending = spawn.pending()
    if #pending > 0 then
      for i = 1, #pending do
        local e = pending[i]
        if e then self.world:add(e) end
      end
      spawn.drain()
    end
  end
  return sys
end

