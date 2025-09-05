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
local Citizen = require('components.citizen')
local Home = require('Zones.home')

describe('citizen goes home to sleep', function()
  it('seeks a home when fatigued and sleeps until rested', function()
    local w = tiny.world(Zones(), Agents(), Move())
    local home = Home.new(0, 0, 30, 20, { label = 'Home' })
    home.on_tick = Home.on_tick
    w:add(home)
    local c = Citizen.new({ x = 60, y = 10, speed = 120, radius = 4,
      fatigue = 0, fatigue_rate = 5.0, rest_rate = 1.0, sleep_rate = 8.0,
      fatigue_max = 2.0, fatigue_min = 0.2,
      work_def = { initial='idle', states={ idle={ update=function(e) e.vel.x,e.vel.y=0,0 end } } }
    })
    w:add(c)
    -- Run updates until fatigue triggers go-home, and then sleep completes
    local went_sleeping, back_to_work = false, false
    for _=1,200 do
      w:update(0.05)
      if c.fsm and c.fsm.current == 'sleeping' then went_sleeping = true end
      if went_sleeping and (c.fsm and c.fsm.current == 'working') then back_to_work = true; break end
    end
    assert.is_true(went_sleeping)
    assert.is_true(back_to_work)
    assert.is_true((c.fatigue or 0) <= (c.fatigue_min or 0.2))
  end)
end)

