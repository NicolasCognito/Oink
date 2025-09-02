package.path = table.concat({
  package.path,
  'libs/?.lua',
  'libs/?/init.lua',
  'libs/tiny-ecs/?.lua',
  'libs/tiny-ecs/?/init.lua',
  'src/?.lua',
  'src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Move = require('systems.move')

describe('move system', function()
  it('moves entities with pos and vel', function()
    local w = tiny.world(Move())
    local e = { pos = { x = 0, y = 0 }, vel = { x = 10, y = -5 } }
    w:add(e)
    w:update(0.5)
    assert.are.equal(5, e.pos.x)
    assert.are.equal(-2.5, e.pos.y)
  end)
end)

