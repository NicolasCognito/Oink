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
  sys.player = nil

  function sys:onAddToWorld(world)
    -- Find player entity once
    for i = 1, #world.entities do
      local e = world.entities[i]
      if e and e.player then self.player = e; break end
    end
  end

  function sys:preProcess(dt)
    if self.player and self.world.entities[self.player] then
      return
    end
    -- (Re)discover player if missing or was added later
    self.player = nil
    local world = self.world
    for i = 1, #world.entities do
      local e = world.entities[i]
      if e and e.player then self.player = e; break end
    end
  end

  function sys:process(e, dt)
    local p = self.player
    if not p or not p.pos then return end
    local pr = p.radius or 0
    local cr = e.radius or 0
    if collision.circles_overlap(p.pos, pr, e.pos, cr) then
      p.score = (p.score or 0) + 1
      self.world:remove(e)
    end
  end

  return sys
end
