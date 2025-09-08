package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Context = require('systems.context_provider')

describe('bear trap zone', function()
  it('kills first agent entering and deactivates', function()
    local w = tiny.world(Context(), Zones())
local BearTrap = require('Zones.bear_trap')
local trap = BearTrap.new(10,10,20,20)
trap.on_tick = BearTrap.on_tick
    local agent = { pos={x=0,y=0}, vel={x=0,y=0}, agent=true }
    w:add(trap); w:add(agent)
    w:update(0) -- apply
    -- Move agent into the trap
    agent.pos.x, agent.pos.y = 15, 15
    w:add(agent) -- mark changed
    w:update(0.016)
    -- Removal is queued; apply next
    w:update(0)
    assert.is_false(trap.active)
    for i=1,#w.entities do
      assert.is_true(w.entities[i] ~= agent)
    end
  end)
end)
