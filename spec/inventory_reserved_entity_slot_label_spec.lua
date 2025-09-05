package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local Inventory = require('inventory')

describe('reserved entity slot preserves label', function()
  it('keeps reserved name before, during, and after holding an entity', function()
    local inv = Inventory.new(5)
    -- Reserve slot 2 for passengers with accept=agent
    Inventory.reserve_slot(inv, 2, 'passenger', {
      accept = function(_, item) return item and item.agent == true end
    })
    -- Initially: label should be 'passenger', count/value zero
    assert.is_true(inv.slots[2] ~= nil)
    assert.are.equal('passenger', inv.slots[2].name)
    assert.are.equal(0, inv.slots[2].count or 0)
    assert.are.equal(0, inv.slots[2].value or 0)

    -- Add a persistent agent entity (e.g., zombie)
    local zombie = { agent = true, collectable = { name='zombie', value=5, persistent=true } }
    assert.is_true(Inventory.add_entity(inv, zombie))
    -- While holding the entity, name should remain the reserved label
    assert.are.equal('passenger', inv.slots[2].name)
    assert.is_not_nil(inv.slots[2].entity)

    -- Remove it and ensure label and slot persist with zero count/value
    local removed = Inventory.remove_one(inv, 2)
    assert.is_not_nil(removed)
    assert.is_true(inv.slots[2] ~= nil)
    assert.are.equal('passenger', inv.slots[2].name)
    assert.is_nil(inv.slots[2].entity)
    assert.are.equal(0, inv.slots[2].count or 0)
    assert.are.equal(0, inv.slots[2].value or 0)
  end)
end)

