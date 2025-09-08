package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local H_zone_mode = require('input.handlers.zone_mode')
local TV = require('Zones.time_vortex')

describe('time zone mode input handler', function()
  it('rotates modes and updates zone.scale via on_mode_change', function()
    local z = TV.new(0,0,40,40, { modes = {
      { name = 'Stasis', scale = 0.3 },
      { name = 'Haste',  scale = 2.5 },
    } })
    -- Prepare a snapshot with an agent inside to verify immediate effect
    local agent = { agent=true, pos={x=10,y=10}, vel={x=0,y=0} }
    local snapshot = { agents = { agent }, zones = { z } }
    z.on_tick = TV.on_tick
    -- Constructor should attach the mode-change hook automatically
    assert.is_truthy(z.on_mode_change)
    -- Initial apply (Stasis)
    TV.on_tick(z, snapshot)
    assert.are.equal(0.3, agent._time_scale_vortex)

    -- Simulate pressing 'E' once via handler
    local h = H_zone_mode({ repeat_rate = 0.25 })
    local input = { repeatPressed = function(key, rate, dt) return key == 'e' end }
    h.on(h, z, snapshot, input, 0.016)

    -- After rotation, first mode is Haste, and zone.scale updated
    assert.are.equal(2.5, z.scale)
    -- And immediate effect reflects in agent scale when on_tick runs again
    TV.on_tick(z, snapshot)
    assert.are.equal(2.5, agent._time_scale_vortex)
  end)
end)
