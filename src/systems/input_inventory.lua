package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')
local IH = require('input.helpers')
local H_inventory = require('input.handlers.inventory')

return function()
  -- A thin wrapper around the shared inventory handler so specs that require this system still pass
  local sys = tiny.system()
  sys._prev = {}
  sys._h_inventory = H_inventory({})

  function sys:update(dt)
    local input = IH.build_state(self._prev)
    local holder = avatar.get(self.world)
    if not holder then
      for i = 1, #self.world.entities do
        local e = self.world.entities[i]
        if e and e.player and e.inventory then holder = e; break end
      end
    end
    if holder then
      local snapshot = require('ctx').get(self.world, dt)
      self._h_inventory.on(self._h_inventory, holder, snapshot, input, dt)
    end
    input.commit()
  end

  return sys
end
