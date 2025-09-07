package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')
local IH = require('input.helpers')
local H_mount = require('input.handlers.mount')

return function()
  -- Thin wrapper around shared mount handler
  local sys = tiny.system()
  sys._prev = {}
  sys._h_mount = H_mount({})

  function sys:update(dt)
    local input = IH.build_state(self._prev)
    local a = avatar.get(self.world)
    if a then
      local snapshot = require('ctx').get(self.world, dt)
      self._h_mount.on(self._h_mount, a, snapshot, input, dt)
    end
    input.commit()
  end

  return sys
end
