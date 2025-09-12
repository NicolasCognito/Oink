local Agent = require('components.agent')

local function new_miner(opts)
  opts = opts or {}
  local e = Agent.new(opts)
  e.miner = true
  e.label = e.label or 'Miner'
  e.color = e.color or {0.8, 0.7, 0.3, 1}
  e.speed = e.speed or 90
  e.brain = { fsm_def = require('FSMs.miner') }
  return e
end

return { new = new_miner }

