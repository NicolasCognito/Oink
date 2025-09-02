package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Collect = require('systems.collect')

describe('collect system', function()
  it('removes coin and increments score on overlap', function()
    local sys = Collect()
    local w = tiny.world(sys)
local Inventory = require('inventory')
local player = { pos = {x=0,y=0}, radius = 5, player = true, collector = true, inventory = Inventory.new(5),
  accept_collectable = function(self, item) return item and item.collectable and item.collectable.name=='coin' end }
local coin = { pos = {x=3,y=4}, radius = 1, coin = true, collectable = { name='coin', value = 1 } }
    w:add(player)
    w:add(coin)
    -- first update applies additions
    w:update(0)
    -- run processing; coin overlaps with player (distance 5, radii sum 6)
    w:update(0.016)
    -- removal is queued; apply on next manage
    w:update(0)
    -- verify coin removed and score incremented
    assert.are.equal(1, player.inventory.count)
    assert.are.equal(1, player.inventory.value)
    for i = 1, #w.entities do
      assert.is_true(w.entities[i] ~= coin)
    end
  end)
end)
