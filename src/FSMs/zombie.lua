-- Declarative FSM definition for a simple zombie.
-- States: idle, chase. Transitions based on distance to the player.

local move = require('ai.movement')

return {
  initial = 'idle',
  states = {
    idle = {
      enter = function(e)
        e.vel.x, e.vel.y = 0, 0
      end,
      update = function(e)
        -- idle does nothing per tick
      end,
      transitions = {
        {
          to = 'chase',
          when = function(e, ctx)
            local p = ctx.player
            if not p or not p.pos then return false end
            local th = (ctx.zombie_aggro or e.aggro or 120)
            return move.within(e.pos, p.pos, th)
          end
        }
      }
    },
    chase = {
      enter = function(e)
        -- could set animation flag here
      end,
      update = function(e, ctx, dt)
        local p = ctx.player
        if not p or not p.pos then e.vel.x, e.vel.y = 0, 0; return end
        local speed = e.speed or (ctx.zombie_speed or 60)
        e.vel.x, e.vel.y = move.seek(e.pos, p.pos, speed)
      end,
      transitions = {
        {
          to = 'idle',
          when = function(e, ctx)
            local p = ctx.player
            if not p or not p.pos then return true end
            local th = (ctx.zombie_aggro or e.aggro or 120)
            return not move.within(e.pos, p.pos, th)
          end
        }
      }
    }
  }
}
