local function new_player(opts)
  opts = opts or {}
  local Inventory = require('inventory')
  local Agent = require('components.agent')
  local e = Agent.new({
    x = opts.x or 20,
    y = opts.y or 60,
    speed = opts.speed or 140,
    radius = opts.radius or 6,
    drawable = true,
    label = opts.label or 'Player',
  })
  e.controllable = true
  e.collector = true
  e.player = true
  e.inventory = Inventory.new(opts.inventory_cap or 20)
  -- Reserve slot 1 for coins (permanent; drops to count=0 when emptied)
  Inventory.reserve_slot(e.inventory, 1, 'coin')
  -- Reserve slot 2 for agents (e.g., passengers); accepts only entity items with agent=true
  Inventory.reserve_slot(e.inventory, 2, 'passenger', {
    accept = function(slot, item)
      -- item may be an entity or a record descriptor {name,value}
      if item and item.agent then return true end
      return false
    end
  })
  -- Player collects every collectable by default; override if needed
  e.accept_collectable = function(self, item)
    return item ~= nil and item.collectable ~= nil
  end
  return e
end

return {
  new = new_player
}
