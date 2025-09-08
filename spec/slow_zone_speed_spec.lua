package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local TD = require('Zones.time_distortion')
local InputProfiles = require('input.profiles')

describe('slow zone affects velocity', function()
  it('zone scales velocity after handler sets it', function()
    local e = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, speed=100 }
    -- Attach character handler via profiles (should use dynamic speed)
    InputProfiles.ensure(e)
    assert.is_truthy(e.input_handlers and #e.input_handlers > 0)
    local h
    for i = 1, #e.input_handlers do
      if e.input_handlers[i].kind == 'character' then h = e.input_handlers[i]; break end
    end
    assert.is_truthy(h)

    -- Fake input: always move right, normalized
    local input = { axis = {
      move = function() return 1, 0 end,
      normalize = function(ax, ay)
        local mag = math.sqrt(ax*ax + ay*ay)
        if mag > 0 then return ax/mag, ay/mag end
        return 0, 0
      end,
    }}

    -- Baseline: handler sets vel to speed (100)
    h.on(h, e, {}, input, 0.016)
    assert.are.equal(100, e.vel.x)

    -- Apply slow zone covering the entity; scales vel to 50 without changing speed
    local z = TD.new(-10, -10, 20, 20, { factor = 0.5 })
    z.on_tick = TD.on_tick
    TD.on_tick(z, { agents = { e } })
    assert.are.equal(50, e.vel.x)
  end)
end)
