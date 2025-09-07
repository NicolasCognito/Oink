local function new_player(opts)
  opts = opts or {}
  local Inventory = require('inventory')
  local match = require('entity_match')
  local Agent = require('components.agent')
  local H_character = require('input.handlers.character')
  local H_inventory = require('input.handlers.inventory')
  local H_mount = require('input.handlers.mount')
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
  e.driver = true
  e.inventory = Inventory.new(opts.inventory_cap or 20)
  -- Reserved slot 1 for coins: standardized behavior, accept only coins; show Coin: x0 when empty
  Inventory.reserve_slot(e.inventory, 1, 'coin')
  -- Custom slot 2 for passengers: not reserved, but persistent UI with default label; only accepts agents
  Inventory.define_slot(e.inventory, 2, {
    default_name = 'passenger',
    accept = function(_, item)
      return item and item.agent == true
    end,
  })
  -- Policy: accept any collectable; rely on global self-protection in Collect system
  e.collect_query = match.build_query({ whitelist = { all_of = {'collectable'} } })
  -- Back-compat fallback: accept any collectable (self-protection is enforced by Collect system)
  e.accept_collectable = function(self, item)
    return item ~= nil and item.collectable ~= nil
  end
  -- Attach input handlers: movement, inventory, mount
  e.input_handlers = e.input_handlers or {}
  table.insert(e.input_handlers, H_character({ speed = e.speed }))
  table.insert(e.input_handlers, H_inventory({}))
  table.insert(e.input_handlers, H_mount({}))
  return e
end

return {
  new = new_player
}
