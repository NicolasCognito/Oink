package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local Inventory = require('inventory')

describe('reserved slot with entity persists accept after remove', function()
  it('keeps slot table and accept after dropping persistent entity', function()
    local inv = Inventory.new(5)
    local function accept_agent(_, item) return item and item.agent == true end
    Inventory.reserve_slot(inv, 2, 'passenger', { accept = accept_agent })
    local passenger = { agent = true, collectable = { name='agent', value=0, persistent=true } }
    assert.is_true(Inventory.add_entity(inv, passenger))
    -- Now remove from slot 2
    local removed = Inventory.remove_one(inv, 2)
    assert.is_not_nil(removed)
    -- Slot 2 should still exist and have accept function
    assert.is_true(inv.slots[2] ~= nil)
    assert.is_true(type(inv.slots[2].accept) == 'function')
    assert.are.equal(0, inv.slots[2].count or 0)
    assert.are.equal(0, inv.slots[2].value or 0)
  end)
end)

