require('spec.support.love_stub')
package.path = table.concat({ package.path,
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

local Citizen = require('BTs.citizen')
local Zombie  = require('BTs.zombie')

local function sim(world, steps, dt)
  dt = dt or (1/60)
  for i=1,steps do world:update(dt) end
end

describe('Citizen behavior — flee and work', function()
  it('works (collector subtree) when no zombie around (long sim)', function()
    local world = World.create()
    local c = compose(pos.new(0,0), vel.new(0,0)); c.living = true; c.profession = 'collector'; c.speed = 140
    c.bt = bt.instance(Citizen.build({ sense_radius=300, flee_distance=120 }), {})
    world:add(c)
    local k = compose(pos.new(80,0), coin.new(1)); world:add(k)
    world:refresh()
    sim(world, 1200) -- 20 seconds @60 FPS
    assert.is_true(k._dead == true)
    assert.is_truthy(c.carrying)
  end)

  it('flees when a nearby zombie exists (distance increases)', function()
    local world = World.create()
    local c = compose(pos.new(0,0), vel.new(0,0)); c.living = true; c.profession = 'collector'; c.speed = 140
    c.bt = bt.instance(Citizen.build({ sense_radius=500, flee_distance=150, flee_speed=160 }), {})
    world:add(c)
    local z = compose(pos.new(50,0), vel.new(0,0)); z.zombie = true; z.speed = 0
    z.bt = bt.instance(Zombie.build({ sense_radius=500 }), {})
    world:add(z)
    world:refresh()
    local d0 = math.abs(c.pos.x - z.pos.x)
    sim(world, 360)
    local d1 = math.abs(c.pos.x - z.pos.x)
    assert.is_true(d1 > d0)
  end)

  it('works when zombie is sensed but safely distant', function()
    local world = World.create()
    local c = compose(pos.new(0,0), vel.new(0,0)); c.living = true; c.profession = 'collector'; c.speed = 140
    c.bt = bt.instance(Citizen.build({ sense_radius=500, flee_distance=140 }), {})
    local z = compose(pos.new(400,0), vel.new(0,0)); z.zombie = true; z.speed = 0
    z.bt = bt.instance(Zombie.build({ sense_radius=500 }), {})
    world:add(c); world:add(z)
    local k = compose(pos.new(60,0), coin.new(1)); world:add(k)
    world:refresh()
    sim(world, 900)
    assert.is_true(k._dead == true)
    assert.is_truthy(c.carrying)
  end)

  it('switches from work to flee when zombie approaches, then returns to work after zombie removed', function()
    local world = World.create()
    local c = compose(pos.new(0,0), vel.new(0,0)); c.living = true; c.profession = 'collector'; c.speed = 140
    c.bt = bt.instance(Citizen.build({ sense_radius=500, flee_distance=140 }), {})
    local z = compose(pos.new(600,0), vel.new(0,0)); z.zombie = true; z.speed = 0
    z.bt = bt.instance(Zombie.build({ sense_radius=500 }), {})
    local k = compose(pos.new(80,0), coin.new(1))
    world:add(c); world:add(z); world:add(k)
    world:refresh()
    -- Work phase
    sim(world, 300)
    -- Threat approaches
    z.pos.x = 60; world:refresh()
    local d0 = math.abs(c.pos.x - z.pos.x)
    sim(world, 240)
    local d1 = math.abs(c.pos.x - z.pos.x)
    assert.is_true(d1 > d0)
    -- Remove threat
    world:removeEntity(z); z._dead = true
    sim(world, 60)
    -- Should resume working: approach coin again
    local initial = math.sqrt((k.pos.x - c.pos.x)^2 + (k.pos.y - c.pos.y)^2)
    local decreased = false
    for i=1,600 do
      world:update(1/60)
      local d = math.sqrt((k.pos.x - c.pos.x)^2 + (k.pos.y - c.pos.y)^2)
      if d < initial then decreased = true; break end
    end
    assert.is_true(decreased)
    -- Eventually collect
    sim(world, 3600)
    assert.is_true(k._dead == true)
    assert.is_truthy(c.carrying)
  end)
end)
