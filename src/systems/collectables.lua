package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')

return function()
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('collectable')

  function sys:process(e, dt)
    -- per-item tick callback support
    if e.on_collectable_tick then
      e.on_collectable_tick(e, dt, self.world)
    end
    -- simple expiry support
    if e.expire_ttl then
      e.expire_age = (e.expire_age or 0) + (dt or 0)
      if e.expire_age >= e.expire_ttl then
        e.marked_for_destruction = true
      end
    end
  end

  return sys
end

