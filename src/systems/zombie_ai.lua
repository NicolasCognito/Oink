package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local fsm = require('fsm')
local zombie_def = require('FSMs.zombie')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('zombie', 'pos', 'vel')
  sys.player = nil
  sys.ctx = { zombie_speed = opts.speed, zombie_aggro = opts.aggro }

  function sys:preProcess(dt)
    -- ensure player reference
    if not self.player or not self.world.entities[self.player] then
      self.player = nil
      for i = 1, #self.world.entities do
        local e = self.world.entities[i]
        if e and e.player then self.player = e; break end
      end
    end
    self.ctx.player = self.player
  end

  function sys:process(e, dt)
    -- attach FSM if missing
    fsm.ensure(e, zombie_def)
    -- advance FSM
    fsm.step(e, self.ctx, dt)
  end

  return sys
end

