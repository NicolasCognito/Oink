package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Collect = require('systems.collect')

describe('collect system (generic collectors)', function()
  it('credits the overlapping collector and removes the coin', function()
    local sys = Collect()
    local w = tiny.world(sys)
local Inventory = require('inventory')
local c1 = { pos={x=0,y=0}, radius=4, collector=true, inventory = Inventory.new(10),
  accept_collectable = function(self, item) return item and item.collectable and item.collectable.name=='coin' end }
local c2 = { pos={x=100,y=0}, radius=4, collector=true, inventory = Inventory.new(10),
  accept_collectable = function(self, item) return item and item.collectable and item.collectable.name=='coin' end }
local coin = { pos={x=2,y=0}, radius=1, coin=true, collectable = { name='coin', value=1 } }
    w:add(c1); w:add(c2); w:add(coin)
    w:update(0) -- apply
    w:update(0.016) -- process
    w:update(0) -- apply removals
    assert.are.equal(1, c1.inventory.count)
    assert.are.equal(1, c1.inventory.value)
    assert.are.equal(0, c2.inventory.count)
    for i = 1, #w.entities do
      assert.is_true(w.entities[i] ~= coin)
    end
  end)
end)
