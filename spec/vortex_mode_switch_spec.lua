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

describe('time vortex mode switching', function()
  it('updates time_scale immediately for entities already inside', function()
    local w = tiny.world(Context(), Zones())
    local v = TV.new(0, 0, 100, 100, {
      modes = {
        { name = 'Stasis', scale = 0.3 },
        { name = 'Haste',  scale = 2.5 },
      }
    })
    v.on_tick = TV.on_tick
    local agent = { agent=true, pos={x=50,y=50}, vel={x=0,y=0} }
    w:add(v); w:add(agent)

    -- Tick once to apply initial scale (Stasis)
    w:update(0.016)
    assert.are.equal(0.3, agent._time_scale_vortex)

    -- Switch to next mode (Haste) while agent remains inside
    -- Rotate modes and call standardized on_mode_change hook
    local snapshot = { agents = { agent } }
    local prev = v.modes[1]
    table.remove(v.modes, 1)
    table.insert(v.modes, prev)
    local nextm = v.modes[1]
    TV.on_mode_change(v, prev, nextm, snapshot)
    assert.are.equal(2.5, agent._time_scale_vortex)
  end)
end)
