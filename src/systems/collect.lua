package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local collision = require('collision')

return function()
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('coin', 'pos')
  sys.collectors = nil

  local function refresh_collectors(self)
    self.collectors = {}
    local idx = 1
    for i = 1, #self.world.entities do
      local ent = self.world.entities[i]
      if ent and ent.collector and ent.pos then
        self.collectors[idx] = ent
        idx = idx + 1
      end
    end
  end

  function sys:preProcess(dt)
    refresh_collectors(self)
  end

  function sys:process(coin, dt)
    if not self.collectors or #self.collectors == 0 then return end
    local cr = coin.radius or 0
    for i = 1, #self.collectors do
      local c = self.collectors[i]
      local rr = c.radius or 0
      if collision.circles_overlap(c.pos, rr, coin.pos, cr) then
        c.score = (c.score or 0) + 1
        self.world:remove(coin)
        break
      end
    end
  end

  return sys
end
