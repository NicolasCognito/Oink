package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Coin = require('components.coin')

return function(opts)
  opts = opts or {}
  local sys = tiny.system()
  sys.interval = opts.interval or 2
  sys.margin = opts.margin or 8
  sys._timer = 0
  local get_size = opts.get_size or function()
    return love.graphics.getWidth(), love.graphics.getHeight()
  end

  function sys:update(dt)
    self._timer = self._timer + (dt or 0)
    while self._timer >= self.interval do
      self._timer = self._timer - self.interval
      local w, h = get_size()
      local m = self.margin
      local x = m + math.random() * math.max(0, (w - 2*m))
      local y = m + math.random() * math.max(0, (h - 2*m))
      self.world:add(Coin.new(x, y))
    end
  end

  return sys
end

