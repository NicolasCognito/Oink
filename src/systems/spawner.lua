package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Coin = require('components.coin')

-- Spawns a coin every `interval` seconds at a random on-screen position.
-- Options:
--   interval (number): seconds between spawns (default: 2)
--   margin (number): screen-edge margin to keep coins within (default: 8)
--   get_size (function): returns w,h; if absent uses love.graphics.getWidth/Height
--   max_per_tick (number): cap number of spawns per update (default: 1)
return function(opts)
  opts = opts or {}
  local sys = tiny.system()
  sys.timer = 0
  sys.interval = opts.interval or 2
  sys.margin = opts.margin or 8
  sys.max_per_tick = opts.max_per_tick or 1
  local get_size = opts.get_size or function()
    return love.graphics.getWidth(), love.graphics.getHeight()
  end

  local function spawn_one()
    local w, h = get_size()
    local m = sys.margin
    local x = m + math.random() * math.max(0, (w - 2*m))
    local y = m + math.random() * math.max(0, (h - 2*m))
    sys.world:add(Coin.new(x, y))
  end

  function sys:update(dt)
    self.timer = self.timer + (dt or 0)
    local spawned = 0
    while self.timer >= self.interval and spawned < self.max_per_tick do
      self.timer = self.timer - self.interval
      spawn_one()
      spawned = spawned + 1
    end
  end

  return sys
end

