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
    local c1 = { pos={x=0,y=0}, radius=4, collector=true, score=0 }
    local c2 = { pos={x=100,y=0}, radius=4, collector=true, score=0 }
    local coin = { pos={x=2,y=0}, radius=1, coin=true }
    w:add(c1); w:add(c2); w:add(coin)
    w:update(0) -- apply
    w:update(0.016) -- process
    w:update(0) -- apply removals
    assert.are.equal(1, c1.score)
    assert.are.equal(0, c2.score)
    for i = 1, #w.entities do
      assert.is_true(w.entities[i] ~= coin)
    end
  end)
end)

