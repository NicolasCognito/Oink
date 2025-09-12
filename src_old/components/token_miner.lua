local Agent = require('components.agent')

local function new_token_miner(opts)
  opts = opts or {}
  local e = Agent.new(opts)
  e.miner = true
  e.label = e.label or 'TokenMiner'
  e.color = e.color or {0.6, 0.9, 0.4, 1}
  e.speed = e.speed or 90
  e.brain = { fsm_def = require('FSMs.token_miner') }
  -- Work token drop tuning
  e.work_drop_interval = opts.work_drop_interval or 0.6
  e.work_drop_radius = opts.work_drop_radius or 6
  e.work_token_ttl = opts.work_token_ttl or 2.0
  return e
end

return { new = new_token_miner }

