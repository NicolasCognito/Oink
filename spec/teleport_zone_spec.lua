package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Context = require('systems.context_provider')
local Teleport = require('Zones.teleport')
local Player = require('components.player')
local Coin = require('components.coin')

describe('teleport zone', function()
  it('teleports an agent on enter', function()
    local w = tiny.world(Context(), Zones())
    local z = Teleport.new(0,0,20,20, { tx = 100, ty = 200, enabled = true })
    z.on_tick = Teleport.on_tick
    local p = Player.new({ x = 10, y = 10, speed = 0 })
    w:add(z); w:add(p)
    -- first tick: agent is inside and should be teleported
    w:update(0.016)
    assert.are.equal(100, p.pos.x)
    assert.are.equal(200, p.pos.y)
  end)

  it('teleports a collectable on enter', function()
    local w = tiny.world(Context(), Zones())
    local z = Teleport.new(0,0,20,20, { tx = 50, ty = 60, enabled = true })
    z.on_tick = Teleport.on_tick
    local c = Coin.new(10, 10, {})
    w:add(z); w:add(c)
    w:update(0.016)
    assert.are.equal(50, c.pos.x)
    assert.are.equal(60, c.pos.y)
  end)

  it('panel on right half toggles teleport via P', function()
    local w = tiny.world(Context(), Zones())
    local z = Teleport.new(0,0,20,20, { tx = 5, ty = 5, enabled = true })
    z.on_tick = Teleport.on_tick
    local p = Player.new({ x = 15, y = 10, speed = 0 }) -- right half
    w:add(z); w:add(p)
    -- Toggle off while in right half via on_input
    local input = { pressed = function(k) return k == 'p' end }
    -- Call the zone's on_input directly with player in ctx
    z.on_input(z, input, { world = w, player = p })
    -- Move to left half and verify no teleport when disabled
    p.pos.x, p.pos.y = 6, 10
    w:update(0.016)
    assert.are_not.equal(5, p.pos.x)
    assert.are.equal(10, p.pos.y)
    -- Toggle back on
    p.pos.x, p.pos.y = 15, 10
    z.on_input(z, input, { world = w, player = p })
    -- Process a tick to clear left-half membership
    w:update(0)
    -- Enter left and verify teleport
    p.pos.x, p.pos.y = 6, 10
    w:update(0.016)
    assert.are.equal(5, p.pos.x)
    assert.are.equal(5, p.pos.y)
  end)

  -- panel control removed; teleport is always active on enter
end)
