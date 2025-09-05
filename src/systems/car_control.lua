package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')

return function()
  local sys = tiny.system()

  function sys:update(dt)
    local entities = self.world.entities or {}
    for i = 1, #entities do
      local car = entities[i]
      if car and car.car == true and car.inventory then
        local s = car.inventory.slots and car.inventory.slots[1]
        local has_driver = s and s.entity ~= nil
        if has_driver and not car._had_driver then
          -- Mount: take control of car; disable driver control
          local driver = s.entity
          if driver then driver.controllable = false end
          car.controllable = true
          avatar.set(self.world, car)
          car._last_driver = driver
          car._had_driver = true
        elseif (not has_driver) and car._had_driver then
          -- Dismount: restore driver control; relinquish car control
          car.controllable = false
          local driver = car._last_driver
          if driver then
            driver.controllable = true
            avatar.set(self.world, driver)
          end
          car._last_driver = nil
          car._had_driver = false
        end
      end
    end
  end

  return sys
end

