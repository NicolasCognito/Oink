package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local move = require('ai.movement')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = function(self, e)
    return e.collector and e.pos and e.vel and not e.controllable
  end

  function sys:preProcess(dt)
    -- Gather current coins
    self._coins = {}
    local idx = 1
    for i = 1, #self.world.entities do
      local ent = self.world.entities[i]
      if ent and ent.coin and ent.pos then
        self._coins[idx] = ent
        idx = idx + 1
      end
    end
  end

  function sys:process(e, dt)
    -- Find nearest coin
    local coins = self._coins
    if not coins or #coins == 0 then
      e.vel.x, e.vel.y = 0, 0
      return
    end
    local best, bestd2
    for i = 1, #coins do
      local c = coins[i]
      local d2 = move.dist2(e.pos, c.pos)
      if not best or d2 < bestd2 then
        best, bestd2 = c, d2
      end
    end
    local vx, vy = move.seek(e.pos, best.pos, e.speed or 0)
    e.vel.x, e.vel.y = vx, vy
  end

  return sys
end

