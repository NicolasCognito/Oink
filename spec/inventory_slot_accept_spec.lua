package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local Inventory = require('inventory')

describe('inventory slot accept', function()
  it('respects reserved slot accept for agents', function()
    local inv = Inventory.new(5)
    Inventory.reserve_slot(inv, 1, 'coin')
    Inventory.define_slot(inv, 2, {
      default_name = 'passenger',
      accept = function(_, item) return item and item.agent == true end,
    })
    -- Add a coin record; should not go into slot 2
    assert.is_true(Inventory.add(inv, 'coin', 1))
    -- Verify coin stacked in slot 1
    assert.is_true(inv.slots[1] and inv.slots[1].name == 'coin' and inv.slots[1].count == 1)
    -- Add an agent entity; should prefer slot 2 due to accept
    local agent = { agent = true, collectable = { name='agent', value=0, persistent=true } }
    assert.is_true(Inventory.add_entity(inv, agent))
    assert.is_true(inv.slots[2] and inv.slots[2].entity == agent)
  end)
end)
