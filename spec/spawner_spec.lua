package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Spawner = require('systems.spawner')

describe('spawner system', function()
  it('spawns coins on interval', function()
    local w = tiny.world(Spawner({ interval = 0.1, get_size = function() return 100, 80 end }))
    assert.is_true(#w.entities == 0)
    w:update(0.05) -- no spawn yet
    assert.is_true(#w.entities == 0)
    w:update(0.05) -- reaches 0.1
    -- Newly spawned entities are applied on the next tick
    w:update(0)
    assert.is_true(#w.entities >= 1)
    local count = #w.entities
    w:update(0.21)
    w:update(0)
    assert.is_true(#w.entities >= count + 2)
  end)
end)
