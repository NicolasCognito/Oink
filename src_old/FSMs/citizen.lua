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
        -- Ensure hunger FSM exists
        multi.ensure(e, 'hunger', require('FSMs.hunger'))
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        e._activity_mode = 'working'
        -- Step hunger first; it may suspend work
        multi.step(e, 'hunger', ctx, dt)
        -- Accumulate fatigue while working
        e.fatigue = (e.fatigue or 0) + (e.fatigue_rate or 1) * dt
        -- Step underlying work FSM if present
        if (not e._suspend_work) and e.brain and e.brain.work_def then
          multi.step(e, 'work', ctx, dt)
        end
      end,
      transitions = {
        {
          to = 'going_home',
          when = function(e, ctx)
            if (e.fatigue or 0) < (e.fatigue_max or 10) then return false end
            -- only go home if at least one home exists
            local zones = ctx and ctx.zones or {}
            for i = 1, #zones do if zones[i] and zones[i].type == 'home' then return true end end
            return false
          end
        },
        {
          to = 'vacation',
          when = function(e)
            return (e.fatigue or 0) >= (e.fatigue_max or 10)
          end,
        }
      }
    },
    going_home = {
      enter = function(e)
        e._home_target = nil
      end,
      update = function(e, ctx, dt)
        local move = require('ai.movement')
        local zones = ctx.zones or {}
        local best, bestd
        for i = 1, #zones do
          local z = zones[i]
          if z and z.type == 'home' and z.rect and e.pos then
            local cx, cy = z.rect.x + z.rect.w * 0.5, z.rect.y + z.rect.h * 0.5
            local d2 = move.dist2(e.pos, {x=cx,y=cy})
            if not best or d2 < bestd then best, bestd = z, d2 end
          end
        end
        e._home_target = best
        if best and best.rect and e.pos then
          local cx, cy = best.rect.x + best.rect.w * 0.5, best.rect.y + best.rect.h * 0.5
          e.vel.x, e.vel.y = move.seek(e.pos, {x=cx,y=cy}, e.speed or 0)
        else
          e.vel.x, e.vel.y = 0, 0
        end
      end,
      transitions = {
        {
          to = 'sleeping',
          when = function(e)
            local Coll = require('collision')
            local z = e._home_target
            return z and z.rect and e.pos and Coll.rect_contains_point(z.rect, e.pos.x, e.pos.y)
          end
        },
        {
          to = 'vacation',
          when = function(e, ctx)
            -- fallback if no home exists
            local zones = ctx and ctx.zones or {}
            for i = 1, #zones do if zones[i] and zones[i].type == 'home' then return false end end
            return true
          end
        }
      }
    },
    sleeping = {
      enter = function(e)
        -- stop moving while sleeping
        e.vel.x, e.vel.y = 0, 0
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        e._activity_mode = 'resting'
        -- Reduce fatigue faster when sleeping; consider zone bonus
        local rate = (e.sleep_rate or 6)
        local z = e._home_target
        if z and z.sleep_rate_bonus then rate = rate + z.sleep_rate_bonus end
        e.fatigue = math.max(0, (e.fatigue or 0) - rate * dt)
        -- Hunger continues to tick slowly via hunger FSM
        local multi = require('fsm_multi')
        multi.ensure(e, 'hunger', require('FSMs.hunger'))
        multi.step(e, 'hunger', ctx, dt)
        -- If pushed out of home, try to go back
        local Coll = require('collision')
        if not (z and z.rect and e.pos and Coll.rect_contains_point(z.rect, e.pos.x, e.pos.y)) then
          -- lost the home rect
          e.fsm.current = 'going_home'
        end
      end,
      transitions = {
        {
          to = 'working',
          when = function(e)
            return (e.fatigue or 0) <= (e.fatigue_min or 2)
          end
        }
      }
    },
    vacation = {
      enter = function(e)
        local Vacationer = require('FSMs.vacationer')
        multi.ensure(e, 'vacation', Vacationer)
        -- Ensure hunger FSM exists
        multi.ensure(e, 'hunger', require('FSMs.hunger'))
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        e._activity_mode = 'resting'
        -- Step hunger first; it may suspend vacation behavior
        multi.step(e, 'hunger', ctx, dt)
        -- Rest handled by vacationer FSM (reduces e.fatigue)
        if not e._suspend_work then
          multi.step(e, 'vacation', ctx, dt)
        end
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
