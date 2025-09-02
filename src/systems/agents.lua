package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local fsm = require('fsm')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = function(self, e)
    return e.pos and e.vel and e.brain and e.brain.fsm_def
  end

  function sys:preProcess(dt)
    -- Build shared context per frame
    self._ctx = { dt = dt }
    -- Locate player
    for i = 1, #self.world.entities do
      local e = self.world.entities[i]
      if e and e.player then self._ctx.player = e; break end
    end
    -- Collect coins list for convenience
    local coins = {}
    local idx = 1
    for i = 1, #self.world.entities do
      local e = self.world.entities[i]
      if e and e.coin and e.pos then
        coins[idx] = e
        idx = idx + 1
      end
    end
    self._ctx.coins = coins
  end

  function sys:process(e, dt)
    fsm.ensure(e, e.brain.fsm_def)
    fsm.step(e, self._ctx, dt)
  end

  return sys
end

