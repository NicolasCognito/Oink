require('spec.support.love_stub')
package.path = table.concat({
  package.path,
  'src/?.lua','src/?/init.lua',
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local World = require('world')
local bt = require('tiny-bt')
local pos = require('components.pos')
local vel = require('components.vel')
local coin = require('components.coin')
local compose = require('components.compose').compose

describe('Collector tree', function()
  it('finds, moves to, and picks up a coin', function()
    local world = World.create()
    -- Agent
    local Collector = require('BTs.collector')
    local c = compose(pos.new(0,0), vel.new(0,0))
    c.speed = 200
    c.bt = bt.instance(Collector.build(), { name='T_Collector' })
    world:add(c)
    -- Coin
    local k = compose(pos.new(50,0), coin.new(1))
    world:add(k)
    world:refresh()
    -- Sim
    for i=1,240 do world:update(1/60) end
    -- Coin should be removed and collector should carry value
    assert.is_true(k._dead == true)
    assert.is_truthy(c.carrying)
  end)

  it('two collectors claim different coins when available', function()
    local world = World.create()
    local Collector = require('BTs.collector')
    local c1 = compose(pos.new(-10,0), vel.new(0,0)); c1.speed = 200; c1.bt = bt.instance(Collector.build(),{})
    local c2 = compose(pos.new(10,0),  vel.new(0,0)); c2.speed = 200; c2.bt = bt.instance(Collector.build(),{})
    world:add(c1); world:add(c2)
    local k1 = compose(pos.new(-20,0), coin.new(1))
    local k2 = compose(pos.new(20,0),  coin.new(1))
    world:add(k1); world:add(k2); world:refresh()
    world:update(0); world:update(0)
    assert.is_truthy(c1.target)
    assert.is_truthy(c2.target)
    assert.not_equal(c1.target, c2.target)
  end)

  it('retargets if coin disappears', function()
    local world = World.create()
    local Collector = require('BTs.collector')
    local c = compose(pos.new(0,0), vel.new(0,0)); c.speed = 200; c.bt = bt.instance(Collector.build(),{})
    world:add(c)
    local a = compose(pos.new(30,0), coin.new(1))
    local b = compose(pos.new(60,0), coin.new(1))
    world:add(a); world:add(b); world:refresh()
    world:update(0); world:update(0)
    assert.is_truthy(c.target)
    local doomed = c.target
    world:removeEntity(doomed); doomed._dead = true
    -- wait until retarget occurs or timeout
    local found = false
    for i=1,180 do
      world:update(1/60)
      if c.target and c.target ~= doomed then found = true; break end
    end
    assert.is_true(found)
  end)
end)

describe('Zombie and Citizen trees', function()
  it('citizen flees from zombie', function()
    local world = World.create()
    local Zombie = require('BTs.zombie')
    local Citizen = require('BTs.citizen')
    local z = compose(pos.new(0,0), vel.new(0,0)); z.zombie = true; z.speed = 120; z.bt = bt.instance(Zombie.build({sense_radius=500}), {})
    local c = compose(pos.new(50,0), vel.new(0,0)); c.living = true; c.speed = 140; c.profession = 'collector'; c.bt = bt.instance(Citizen.build({sense_radius=500}), {})
    world:add(z); world:add(c); world:refresh()
    local d0 = math.abs((c.pos.x - z.pos.x))
    for i=1,120 do world:update(1/60) end
    local d1 = math.abs((c.pos.x - z.pos.x))
    assert.is_true(d1 > d0)
  end)

  it('citizen works (collector subtree) when no zombie around', function()
    local world = World.create()
    local Citizen = require('BTs.citizen')
    -- Citizen with profession collector, no zombies
    local c = compose(pos.new(0,0), vel.new(0,0)); c.living = true; c.speed = 140; c.profession = 'collector'; c.bt = bt.instance(Citizen.build({sense_radius=200}), {})
    world:add(c)
    -- Place a coin
    local k = compose(pos.new(40,0), coin.new(1))
    world:add(k); world:refresh()
    -- Run
    for i=1,240 do world:update(1/60) end
    assert.is_true(k._dead == true)
    assert.is_truthy(c.carrying)
  end)

  it('citizen works even if a distant zombie is sensed (beyond flee distance)', function()
    local world = World.create()
    local Zombie = require('BTs.zombie')
    local Citizen = require('BTs.citizen')
    -- Citizen
    local c = compose(pos.new(0,0), vel.new(0,0)); c.living = true; c.speed = 140; c.profession = 'collector'; c.bt = bt.instance(Citizen.build({sense_radius=500, flee_distance=140}), {})
    world:add(c)
    -- Distant zombie within sense but beyond flee distance
    local z = compose(pos.new(300,0), vel.new(0,0)); z.zombie = true; z.speed = 0; z.bt = bt.instance(Zombie.build({sense_radius=500}), {})
    world:add(z)
    -- Coin to collect
    local k = compose(pos.new(60,0), coin.new(1))
    world:add(k); world:refresh()
    for i=1,360 do world:update(1/60) end
    assert.is_true(k._dead == true)
    assert.is_truthy(c.carrying)
  end)
end)
