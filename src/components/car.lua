local match = require('entity_match')
local Inventory = require('inventory')
local H_vehicle = require('input.handlers.vehicle')
local H_inventory = require('input.handlers.inventory')

local function new_car(opts)
  opts = opts or {}
  local e = {
    agent = true,
    car = true,
    collector = true,
    label = opts.label or 'Car',
    drawable = true,
    pos = { x = opts.x or 200, y = opts.y or 200 },
    vel = { x = 0, y = 0 },
    radius = opts.radius or 10,
    inventory = Inventory.new(1), -- only first slot used
    heading = opts.heading or 0,
  }
  -- Slot 1 accepts only drivers
  Inventory.define_slot(e.inventory, 1, {
    default_name = 'driver',
    accept = function(_, item) return item and item.driver == true end,
  })
  -- Collector policy: accept items that are both collectable and driver
  e.collect_query = match.build_query({
    whitelist = function(_, it)
      return it and it.collectable and it.driver == true
    end
  })
  -- Handlers are attached centrally by input profiles based on components
  return e
end

return { new = new_car }
