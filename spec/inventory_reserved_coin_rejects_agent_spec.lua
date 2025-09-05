package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local Inventory = require('inventory')

describe('reserved coin slot rejects agent entity without accept', function()
  it('keeps agent out of coin slot and routes to agent slot', function()
    local inv = Inventory.new(5)
    -- Slot 1 reserved for coins; no explicit accept
    Inventory.reserve_slot(inv, 1, 'coin')
    -- Slot 2 custom for passengers (persistent UI, not reserved)
    Inventory.define_slot(inv, 2, {
      default_name = 'passenger',
      accept = function(_, item) return item and item.agent == true end
    })

    -- Add a persistent agent entity (e.g., zombie/passenger)
    local agent = { agent = true, collectable = { name='zombie', value=5, persistent=true } }
    assert.is_true(Inventory.add_entity(inv, agent))

    -- Slot 1 should remain empty (reserved for coins)
    assert.is_true(inv.slots[1] ~= nil)
    assert.are.equal(0, inv.slots[1].count or 0)
    assert.is_nil(inv.slots[1].entity)
    assert.are.equal('coin', inv.slots[1].name)

    -- Slot 2 should hold the agent entity
    assert.is_true(inv.slots[2] ~= nil)
    assert.is_not_nil(inv.slots[2].entity)
    assert.are.equal(agent, inv.slots[2].entity)
  end)
end)
