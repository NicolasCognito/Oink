local multi = require('fsm_multi')

return {
  initial = 'working',
  states = {
    working = {
      enter = function(e)
        -- Ensure work FSM exists; definition provided by e.brain.work_def
        if e.brain and e.brain.work_def then
          multi.ensure(e, 'work', e.brain.work_def)
        end
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        -- Accumulate fatigue while working
        e.fatigue = (e.fatigue or 0) + (e.fatigue_rate or 1) * dt
        -- Step underlying work FSM if present
        if e.brain and e.brain.work_def then
          multi.step(e, 'work', ctx, dt)
        end
      end,
      transitions = {
        {
          to = 'vacation',
          when = function(e)
            return (e.fatigue or 0) >= (e.fatigue_max or 10)
          end,
        }
      }
    },
    vacation = {
      enter = function(e)
        local Vacationer = require('FSMs.vacationer')
        multi.ensure(e, 'vacation', Vacationer)
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        -- Rest handled by vacationer FSM (reduces e.fatigue)
        multi.step(e, 'vacation', ctx, dt)
      end,
      transitions = {
        {
          to = 'working',
          when = function(e)
            return (e.fatigue or 0) <= (e.fatigue_min or 2)
          end,
        }
      }
    }
  }
}

