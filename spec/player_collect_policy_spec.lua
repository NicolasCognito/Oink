package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Collect = require('systems.collect')
local Player = require('components.player')

describe('player collect policy', function()
  it('does not collect itself; still collects coins', function()
    local w = tiny.world(Collect())
    local p = Player.new({ x = 10, y = 10, speed = 0, radius = 6, label = 'P' })
    -- Mark player as collectable driver (overlapping self)
    p.collectable = { name='driver', value=0, persistent=true }
    -- Spawn a coin overlapping as well
    local coin = { pos={x=10,y=10}, radius=2, collectable={ name='coin', value=1 } }
    w:add(p); w:add(coin)
    w:update(0)
    -- Process a couple of frames
    w:update(0.016)
    w:update(0)
    -- Player must still be in the world (not self-collected)
    local found_p = false
    for i=1,#w.entities do if w.entities[i] == p then found_p = true end end
    assert.is_true(found_p)
    -- Coin should be collected by the player
    assert.are.equal(1, p.inventory.count)
  end)
end)

