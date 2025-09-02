package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local TD = require('Zones.time_distortion')

describe('time distortion zone', function()
  it('slows agents on enter and restores on exit', function()
    local w = tiny.world(Zones())
    local z = TD.new(0,0,20,20, { factor = 0.5 })
    z.on_tick = TD.on_tick
    local agent = { agent=true, pos={x=30,y=30}, vel={x=0,y=0}, speed = 100 }
    w:add(z); w:add(agent)
    w:update(0) -- apply
    -- outside: unchanged
    w:update(0.016)
    assert.are.equal(100, agent.speed)
    -- move inside
    agent.pos.x, agent.pos.y = 10, 10
    w:add(agent)
    w:update(0) -- apply change
    w:update(0.016)
    assert.are.equal(50, agent.speed)
    -- move outside and ensure restore
    agent.pos.x, agent.pos.y = 30, 30
    w:add(agent)
    w:update(0)
    w:update(0.016)
    assert.are.equal(100, agent.speed)
  end)
end)

