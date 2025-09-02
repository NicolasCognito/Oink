local Agent = require('components.agent')

local function new_chicken(opts)
  opts = opts or {}
  local e = Agent.new({
    x = opts.x or 100,
    y = opts.y or 100,
    speed = opts.speed or 80,
    radius = opts.radius or 5,
    drawable = true,
    label = opts.label or 'Chicken',
  })
  e.chicken = true
  e.color = e.color or {1.0, 0.9, 0.6, 1}
  e.brain = { fsm_def = require('FSMs.chicken') }
  e.wander_change = opts.wander_change or 1.5
  e.egg_interval = opts.egg_interval or 6
  e.egg_ttl = opts.egg_ttl or 15
  return e
end

return { new = new_chicken }

