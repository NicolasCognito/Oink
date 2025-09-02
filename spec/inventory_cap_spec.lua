package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Collect = require('systems.collect')
local Inventory = require('inventory')

describe('inventory cap', function()
  it('prevents collection when full', function()
    local sys = Collect()
    local w = tiny.world(sys)
    local c = { pos={x=0,y=0}, radius=4, collector=true, inventory = Inventory.new(1) }
    local coin1 = { pos={x=0,y=0}, radius=1, coin=true, collectable={name='coin', value=1} }
    local coin2 = { pos={x=0,y=0}, radius=1, coin=true, collectable={name='coin', value=1} }
    w:add(c); w:add(coin1); w:add(coin2)
    w:update(0)
    w:update(0.016)
    w:update(0)
    -- Only one coin should be picked up
    assert.are.equal(1, c.inventory.count)
    -- Second coin remains in world
    local found = false
    for i=1,#w.entities do if w.entities[i] == coin2 then found = true end end
    assert.is_true(found)
  end)
end)

