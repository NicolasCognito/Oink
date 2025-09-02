package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Agents = require('systems.agents')
local ZombieDef = require('FSMs.zombie')

describe('zombie fsm', function()
  it('idles when far and chases when near', function()
    local w = tiny.world(Agents())
    local player = { pos = {x=0,y=0}, radius=6, player=true }
    local zombie = { pos = {x=200,y=0}, vel={x=0,y=0}, radius=6, zombie=true, brain={ fsm_def = ZombieDef }, speed=10, aggro=50 }
    w:add(player)
    w:add(zombie)
    w:update(0) -- apply
    -- Far: stays idle => velocity remains zero after processing
    w:update(0.016)
    assert.are.equal(0, zombie.vel.x)
    assert.are.equal(0, zombie.vel.y)
    -- Move zombie near the player
    zombie.pos.x = 10
    zombie.pos.y = 0
    w:add(zombie) -- mark changed
    w:update(0) -- apply change
    w:update(0.016)
    -- Should now be chasing: velocity points toward player (negative x)
    assert.is_true(zombie.vel.x < 0)
  end)
end)
