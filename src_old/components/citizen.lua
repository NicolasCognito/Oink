local Agent = require('components.agent')
local Inventory = require('inventory')

local function new_citizen(opts)
  opts = opts or {}
  local e = Agent.new(opts)
  e.collector = opts.collector or false
  e.label = e.label or 'Citizen'
  e.color = e.color or {0.6, 0.6, 1.0, 1}
  e.speed = e.speed or 120
  -- brain: citizen composer with a provided work FSM definition
  e.brain = {
    fsm_def = require('FSMs.citizen'),
    work_def = opts.work_def, -- e.g., require('FSMs.tax_collector')
  }
  -- fatigue parameters
  e.fatigue = opts.fatigue or 0
  e.fatigue_rate = opts.fatigue_rate or 1
  e.rest_rate = opts.rest_rate or 4
  e.fatigue_max = opts.fatigue_max or 10
  e.fatigue_min = opts.fatigue_min or 2
  -- sleep parameters (used when sleeping at home)
  e.sleep_rate = opts.sleep_rate or 6
  -- hunger parameters
  e.hunger = opts.hunger or 0
  e.hunger_rate_work = opts.hunger_rate_work or 1.0
  e.hunger_rate_rest = opts.hunger_rate_rest or 0.4
  e.hunger_max = opts.hunger_max or 6
  e.hunger_min = opts.hunger_min or 2
  e.satiate_per_food = opts.satiate_per_food or 4
  e.hungry_speed_multiplier = opts.hungry_speed_multiplier or 0.6
  -- optional inventory/collect behavior for work roles like tax collector
  if opts.inventory_cap or e.collector then
    e.inventory = e.inventory or Inventory.new(opts.inventory_cap or 5)
  end
  if e.collector and not e.accept_collectable then
    e.accept_collectable = function(self, item)
      return item and item.collectable and item.collectable.name == 'coin'
    end
  end
  return e
end

return { new = new_citizen }
