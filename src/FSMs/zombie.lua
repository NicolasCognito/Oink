-- Declarative FSM definition for a simple zombie.
-- States: idle, chase. Transitions based on distance to the player.

local move = require('ai.movement')

local function nearest_player(e, ctx)
  if not ctx or not ctx.query or not e or not e.pos then return nil end
  local players = ctx.query('player') or {}
  local best, bestd
  for i = 1, #players do
    local p = players[i]
    if p and p.pos then
      local d2 = move.dist2(e.pos, p.pos)
      if not best or d2 < bestd then best, bestd = p, d2 end
    end
  end
  return best
end

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
            local p = nearest_player(e, ctx)
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
        local p = nearest_player(e, ctx)
        if not p or not p.pos then e.vel.x, e.vel.y = 0, 0; return end
        local speed = e.speed or (ctx.zombie_speed or 60)
        e.vel.x, e.vel.y = move.seek(e.pos, p.pos, speed)
      end,
      transitions = {
        {
          to = 'idle',
          when = function(e, ctx)
            local p = nearest_player(e, ctx)
            if not p or not p.pos then return true end
            local th = (ctx.zombie_aggro or e.aggro or 120)
            return not move.within(e.pos, p.pos, th)
          end
        }
      }
    }
  }
}
