local Agent = require('components.agent')
local Inventory = require('inventory')

local function new_tax_collector(opts)
  opts = opts or {}
  local e = Agent.new(opts)
  e.collector = true
  e.label = e.label or 'Collector'
  e.color = e.color or {0.2, 0.4, 1.0, 1}
  e.speed = e.speed or 120
  e.inventory = Inventory.new(opts.inventory_cap or 10)
  e.brain = { fsm_def = require('FSMs.tax_collector') }
  return e
end

return { new = new_tax_collector }
