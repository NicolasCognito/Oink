local move = require('ai.movement')

-- Simple vacation/rest behavior: slow wander and reduce fatigue over time.
return {
  initial = 'rest',
  states = {
    rest = {
      enter = function(e)
        e._vac_dirx, e._vac_diry = 0, 0
        e._vac_timer = 0
      end,
      update = function(e, ctx, dt, fsm)
        dt = dt or 0
        -- reduce fatigue
        e.fatigue = math.max(0, (e.fatigue or 0) - (e.rest_rate or 4) * dt)
        -- light wander
        e._vac_timer = (e._vac_timer or 0) + dt
        if e._vac_timer >= 1.0 then
          e._vac_timer = 0
          local angle = math.random() * math.pi * 2
          e._vac_dirx, e._vac_diry = math.cos(angle), math.sin(angle)
        end
        local s = (e.vacation_speed or (e.speed or 60) * 0.25)
        e.vel.x = (e._vac_dirx or 0) * s
        e.vel.y = (e._vac_diry or 0) * s
      end,
    },
  }
}

