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
  sys._prev = {}
  sys._cd = 0

  local function keydown(key)
    return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(key)
  end

  local function pressed(self, key)
    local now = keydown(key)
    local was = self._prev[key] == true
    self._prev[key] = now
    return now and not was
  end

  function sys:update(dt)
    self._cd = math.max(0, (self._cd or 0) - (dt or 0))
    if self._cd > 0 then return end
    if not pressed(self, 'return') then return end
    local a = avatar.get(self.world)
    if not a then return end
    -- Only players can toggle driver collectable; ignore when controlling cars or other entities
    if not a.player then return end
    if a.collectable and a.collectable.persistent and a.collectable.name == 'driver' then
      a.collectable = nil
    else
      a.collectable = { name = 'driver', value = 0, persistent = true }
    end
    -- Mark entity changed so systems with filters notice the component change
    if self.world and self.world.add then self.world:add(a) end
    self._cd = 0.2
  end

  return sys
end
