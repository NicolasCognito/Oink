package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Agents = require('systems.agents')
local Context = require('systems.context_provider')
local ZombieDef = require('FSMs.zombie')

describe('zombie with multiple players', function()
  it('chases nearest player regardless of control', function()
    local w = tiny.world(Context(), Agents())
    local p1 = { pos={x=0,y=0}, radius=6, player=true, controllable=true, label='P1' }
    local p2 = { pos={x=100,y=0}, radius=6, player=true, controllable=true, label='P2' }
    local z = { pos={x=60,y=0}, vel={x=0,y=0}, radius=6, zombie=true, brain={ fsm_def = ZombieDef }, speed=10, aggro=200 }
    w:add(p1); w:add(p2); w:add(z)
    w:update(0)
    -- p2 (at x=100) is closer to z (x=60) than p1 (x=0) -> chase left or right?
    -- Dist to p2: 40, to p1: 60 -> should seek p2 (positive x)
    w:update(0.016)
    assert.is_true(z.vel.x > 0)
    -- Move p2 farther, p1 nearer
    p2.pos.x = 200
    p1.pos.x = 50
    w:add(p2); w:add(p1)
    w:update(0)
    w:update(0.016)
    assert.is_true(z.vel.x < 0)
  end)
end)
