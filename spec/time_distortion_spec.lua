package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Context = require('systems.context_provider')
local TD = require('Zones.time_distortion')

describe('time distortion zone', function()
  it('scales velocity while inside only (no state persisted)', function()
    local w = tiny.world(Context(), Zones())
    local z = TD.new(0,0,20,20, { factor = 0.5 })
    z.on_tick = TD.on_tick
    local agent = { agent=true, pos={x=30,y=30}, vel={x=0,y=0}, speed = 100 }
    w:add(z); w:add(agent)
    w:update(0) -- apply
    -- Frame 1 outside: set base vel, zone should not change
    agent.vel.x, agent.vel.y = 100, 0
    w:update(0.016)
    assert.are.equal(100, agent.vel.x)
    -- Frame 2 inside: set base vel again; zone should scale it
    agent.pos.x, agent.pos.y = 10, 10
    agent.vel.x, agent.vel.y = 100, 0
    w:update(0.016)
    assert.are.equal(50, agent.vel.x)
    -- Frame 3 outside: base vel restored by upstream systems (simulated here)
    agent.pos.x, agent.pos.y = 30, 30
    agent.vel.x, agent.vel.y = 100, 0
    w:update(0.016)
    assert.are.equal(100, agent.vel.x)
  end)
end)
