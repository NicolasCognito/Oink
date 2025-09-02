-- Declarative FSM definition for a simple zombie.
-- States: idle, chase. Transitions based on distance to the player.

local function dist2(a, b)
  local dx, dy = b.pos.x - a.pos.x, b.pos.y - a.pos.y
  return dx*dx + dy*dy
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
            local p = ctx.player
            if not p or not p.pos then return false end
            local th = (ctx.zombie_aggro or 120)
            return dist2(e, p) <= th*th
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
        local dx, dy = p.pos.x - e.pos.x, p.pos.y - e.pos.y
        local len = math.sqrt(dx*dx + dy*dy)
        local speed = e.speed or (ctx.zombie_speed or 60)
        if len > 0 then
          e.vel.x = (dx/len) * speed
          e.vel.y = (dy/len) * speed
        else
          e.vel.x, e.vel.y = 0, 0
        end
      end,
      transitions = {
        {
          to = 'idle',
          when = function(e, ctx)
            local p = ctx.player
            if not p or not p.pos then return true end
            local th = (ctx.zombie_aggro or 120)
            return dist2(e, p) > th*th
          end
        }
      }
    }
  }
}

