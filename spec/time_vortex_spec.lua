package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local TV = require('Zones.time_vortex')

describe('time vortex zone', function()
  it('applies and restores time_scale on enter/exit', function()
    local w = tiny.world(Zones())
    local z = TV.new(0,0,20,20, { scale = 2.0 })
    z.on_tick = TV.on_tick
    local agent = { agent=true, pos={x=30,y=30}, vel={x=0,y=0}, time_scale = 1.3 }
    w:add(z); w:add(agent)
    -- initial outside: unchanged
    w:update(0)
    w:update(0.016)
    assert.are.equal(1.3, agent.time_scale)
    -- move inside
    agent.pos.x, agent.pos.y = 10, 10
    w:add(agent)
    w:update(0)
    w:update(0.016)
    assert.are.equal(2.0, agent._time_scale_vortex)
    -- move outside and ensure restore to original (1.3)
    agent.pos.x, agent.pos.y = 30, 30
    w:add(agent)
    w:update(0)
    w:update(0.016)
    assert.are.equal(1.0, agent._time_scale_vortex)
  end)
end)
