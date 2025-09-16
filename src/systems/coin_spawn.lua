local tiny = require('tiny')
local comps = require('sim.components')

local function rand_range(a, b)
  return a + math.random() * (b - a)
end

local function process(self, spawner, dt)
  spawner.acc = (spawner.acc or 0) + dt
  local rate = spawner.rate_multiplier or 1.0
  local interval = (spawner.interval or 1.0) / math.max(0.0001, rate)

  -- Count current coins
  local coins = 0
  for _, e in ipairs(self.world.entities) do
    if e.coin then coins = coins + 1 end
  end
  if coins >= (spawner.max_alive or math.huge) then return end

  while spawner.acc >= interval and coins < (spawner.max_alive or math.huge) do
    spawner.acc = spawner.acc - interval
    local a = spawner.area or { x_min = 0, x_max = 800, y_min = 0, y_max = 600 }
    local x = rand_range(a.x_min, a.x_max)
    local y = rand_range(a.y_min, a.y_max)
    local c = comps.new_coin({ x = x, y = y })
    self.world:addEntity(c)
    coins = coins + 1
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('coin_spawner')
  System.name = 'CoinSpawnSystem'
  System.process = function(self, spawner, dt) return process(self, spawner, dt) end
  return System
end
