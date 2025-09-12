local Agent = require('components.agent')

local function new_zombie(opts)
  opts = opts or {}
  local e = Agent.new(opts)
  e.zombie = true
  e.aggro = opts.aggro or 120
  e.color = e.color or {0.3, 0.9, 0.3, 1}
  e.label = e.label or 'Zombie'
  e.brain = { fsm_def = require('FSMs.zombie') }
  return e
end

return { new = new_zombie }
