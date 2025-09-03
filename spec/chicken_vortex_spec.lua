package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Agents = require('systems.agents')
local Move = require('systems.move')
local Spawner = require('systems.spawner')
local Expiry = require('systems.expiry')
local Destroyer = require('systems.destroyer')
local Chicken = require('components.chicken')
local TV = require('Zones.time_vortex')

local function count_eggs(world)
  local n = 0
  for _, e in ipairs(world.entities) do
    if e and e.collectable and e.collectable.name == 'egg' then n = n + 1 end
  end
  return n
end

describe('chicken under time vortex', function()
  it('lays eggs roughly 2x faster with 2.0x time scale', function()
    -- baseline world (no vortex)
    local w1 = tiny.world(Zones(), Agents(), Move(), Spawner(), Expiry(), Destroyer())
    local c1 = Chicken.new({ x = 10, y = 10, egg_interval = 0.2, egg_ttl = 999, speed = 0 })
    -- keep it still to reduce noise
    c1._dirx, c1._diry = 0, 0
    w1:add(c1)

    -- vortex world
    local w2 = tiny.world(Zones(), Agents(), Move(), Spawner(), Expiry(), Destroyer())
    local z = TV.new(0, 0, 40, 40, { scale = 2.0 })
    z.on_tick = TV.on_tick
    local c2 = Chicken.new({ x = 10, y = 10, egg_interval = 0.2, egg_ttl = 999, speed = 0 })
    c2._dirx, c2._diry = 0, 0
    w2:add(z); w2:add(c2)

    -- simulate equal real time in both worlds
    for _ = 1, 10 do
      w1:update(0.1)
      w2:update(0.1)
    end

    -- drain any pending spawns
    w1:update(0); w2:update(0)

    local e1 = count_eggs(w1)
    local e2 = count_eggs(w2)
    -- With 1s and interval 0.2, baseline ~5 eggs, scaled ~10 eggs
    assert.is_true(e2 >= e1 * 2 - 1)
  end)

  it('does not advance chicken timers when time_scale = 0', function()
    local w = tiny.world(Zones(), Agents(), Move(), Spawner(), Expiry(), Destroyer())
    local z = TV.new(0, 0, 40, 40, { scale = 0.0 })
    z.on_tick = TV.on_tick
    local c = Chicken.new({ x = 10, y = 10, egg_interval = 0.2, egg_ttl = 999, speed = 0 })
    c._dirx, c._diry = 0, 0
    w:add(z); w:add(c)

    for _ = 1, 10 do w:update(0.1) end
    w:update(0)

    assert.are.equal(0, count_eggs(w))
    -- _egg_timer should not have advanced meaningfully
    assert.are.equal(0, c._egg_timer or 0)
  end)

  it('restores original time_scale after exiting the vortex', function()
    local w = tiny.world(Zones())
    local z = TV.new(0, 0, 20, 20, { scale = 2.0 })
    z.on_tick = TV.on_tick
    local c = Chicken.new({ x = 30, y = 30, speed = 0 })
    w:add(z); w:add(c)
    w:update(0); w:update(0.016)
    -- outside: default time scale is 1.0 (implicit)
    assert.is_true((c.time_scale or 1.0) == 1.0)
    -- move inside and apply
    c.pos.x, c.pos.y = 10, 10; w:add(c); w:update(0); w:update(0.016)
    assert.are.equal(2.0, c.time_scale)
    -- move outside and ensure restore to original (1.0)
    c.pos.x, c.pos.y = 30, 30; w:add(c); w:update(0); w:update(0.016)
    assert.are.equal(1.0, c.time_scale)
  end)
end)

