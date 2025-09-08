package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Context = require('systems.context_provider')
local TV = require('Zones.time_vortex')

local function make_counter_zone(x, y, w, h)
  local z = {
    zone = true,
    rect = { x = x, y = y, w = w, h = h },
    label = 'Counter',
    drawable = false,
    accum = 0,
  }
  z.on_tick = function(self, snapshot, dt)
    self.accum = self.accum + (dt or 0)
  end
  return z
end

describe('zones affected by time vortex', function()
  it('ticks ~2x faster when inside 2.0x vortex', function()
    -- baseline world with a counter zone
    local w1 = tiny.world(Context(), Zones())
    local z1 = make_counter_zone(10, 10, 20, 20)
    w1:add(z1)

    -- world with same counter zone inside a 2.0x vortex
    local w2 = tiny.world(Context(), Zones())
    local z2 = make_counter_zone(10, 10, 20, 20)
    local v = TV.new(0, 0, 100, 100, { scale = 2.0 })
    v.on_tick = TV.on_tick
    w2:add(v); w2:add(z2)

    -- Simulate 1s real time in 0.1s steps
    for _ = 1, 10 do
      w1:update(0.1)
      w2:update(0.1)
    end

    -- z2 should have roughly double accumulated dt compared to z1
    assert.is_true(z2.accum >= (z1.accum * 2 - 0.0001))
  end)

  it('pauses zone ticking when inside 0x vortex', function()
    local w = tiny.world(Context(), Zones())
    local z = make_counter_zone(10, 10, 20, 20)
    local v = TV.new(0, 0, 100, 100, { scale = 0.0 })
    v.on_tick = TV.on_tick
    w:add(v); w:add(z)
    for _ = 1, 10 do w:update(0.1) end
    assert.are.equal(0, z.accum)
  end)
end)
