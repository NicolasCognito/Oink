package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Teleport = require('Zones.teleport')
local Player = require('components.player')
local Coin = require('components.coin')

describe('teleport zone', function()
  it('teleports an agent on enter', function()
    local w = tiny.world(Zones())
    local z = Teleport.new(0,0,20,20, { tx = 100, ty = 200 })
    z.on_tick = Teleport.on_tick
    local p = Player.new({ x = 10, y = 10, speed = 0 })
    w:add(z); w:add(p)
    -- first tick: agent is inside and should be teleported
    w:update(0.016)
    assert.are.equal(100, p.pos.x)
    assert.are.equal(200, p.pos.y)
  end)

  it('teleports a collectable on enter', function()
    local w = tiny.world(Zones())
    local z = Teleport.new(0,0,20,20, { tx = 50, ty = 60 })
    z.on_tick = Teleport.on_tick
    local c = Coin.new(10, 10, {})
    w:add(z); w:add(c)
    w:update(0.016)
    assert.are.equal(50, c.pos.x)
    assert.are.equal(60, c.pos.y)
  end)
end)

