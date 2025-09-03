package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Agents = require('systems.agents')

-- Dummy work FSM: increments a counter each update
local WorkFSM = {
  initial = 'work',
  states = {
    work = {
      update = function(e, ctx, dt, fsm)
        e._work_ticks = (e._work_ticks or 0) + 1
      end,
    }
  }
}

describe('citizen composer fsm', function()
  it('switches from working to vacation on fatigue, then back', function()
    local Citizen = require('components.citizen')
    local w = tiny.world(Agents())
    local c = Citizen.new({ work_def = WorkFSM, fatigue_rate = 5, rest_rate = 10, fatigue_max = 2, fatigue_min = 0.5 })
    w:add(c)

    -- Initially working
    w:update(0) -- init
    w:update(0.1)
    assert.is_true(c.fsm.current == 'working')
    local ticks_before = c._work_ticks or 0

    -- Run until fatigue exceeds max and transition triggers (cap attempts)
    local switched = false
    for _=1,20 do
      w:update(0.1)
      if c.fsm.current == 'vacation' then switched = true; break end
    end
    assert.is_true(switched)

    -- While on vacation, work fsm should not tick further
    ticks_before = c._work_ticks or 0
    local steps = 0
    while c.fsm.current == 'vacation' and steps < 10 do
      w:update(0.1)
      steps = steps + 1
    end
    assert.is_true((c._work_ticks or 0) == ticks_before)

    -- After more rest, should return to working
    local back = false
    for _=1,20 do
      w:update(0.1)
      if c.fsm.current == 'working' then back = true; break end
    end
    assert.is_true(back)

    -- After returning to work, work ticks should resume increasing
    local before2 = c._work_ticks or 0
    for _=1,5 do w:update(0.1) end
    assert.is_true((c._work_ticks or 0) > before2)
  end)
end)
