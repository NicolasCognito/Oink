package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Collect = require('systems.collect')
local Car = require('components.car')
local Player = require('components.player')

describe('car collects driver player', function()
  it('car picks up player with driver component into slot 1', function()
    local w = tiny.world(Collect())
    local car = Car.new({ x = 50, y = 50, radius = 8 })
    local p = Player.new({ x = 54, y = 50, speed = 0, radius = 4, label = 'Driver' })
    -- Make player collectable so collect system can pick it up
    p.collectable = { name = 'driver', value = 0, persistent = true }
    w:add(car); w:add(p)
    w:update(0); w:update(0.016); w:update(0)

    -- Player should be removed from world and placed into car's slot 1
    local found = false
    for i = 1, #w.entities do if w.entities[i] == p then found = true end end
    assert.is_false(found)
    assert.is_true(car.inventory.slots[1] ~= nil)
    assert.is_not_nil(car.inventory.slots[1].entity)
    assert.are.equal(p, car.inventory.slots[1].entity)
  end)
end)

