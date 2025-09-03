local move = require('ai.movement')
local Coll = require('collision')

local function find_nearest_mine(ctx, e)
  local zones = ctx.zones or {}
  local best, bestd
  for i = 1, #zones do
    local z = zones[i]
    if z and z.type == 'mine' and z.rect and e.pos then
      local cx, cy = z.rect.x + z.rect.w * 0.5, z.rect.y + z.rect.h * 0.5
      local d2 = move.dist2(e.pos, {x=cx, y=cy})
      if not best or d2 < bestd then best, bestd = z, d2 end
    end
  end
  return best
end

return {
  initial = 'seek_mine',
  states = {
    seek_mine = {
      enter = function(e)
        e._mining = false
        e._mine_target = nil
      end,
      update = function(e, ctx, dt)
        local target = e._mine_target or find_nearest_mine(ctx, e)
        e._mine_target = target
        if not target then
          e.vel.x, e.vel.y = 0, 0
          return
        end
        local cx = target.rect.x + target.rect.w * 0.5
        local cy = target.rect.y + target.rect.h * 0.5
        e.vel.x, e.vel.y = move.seek(e.pos, {x=cx, y=cy}, e.speed or 0)
      end,
      transitions = {
        {
          to = 'work',
          when = function(e)
            local z = e._mine_target
            return z and Coll.rect_contains_point(z.rect, e.pos.x, e.pos.y)
          end
        }
      }
    },
    work = {
      enter = function(e)
        e._mining = true
      end,
      update = function(e, ctx, dt)
        -- Stay roughly in place while working
        e.vel.x, e.vel.y = 0, 0
      end,
      transitions = {
        {
          to = 'seek_mine',
          when = function(e)
            local z = e._mine_target
            return (not z) or (not Coll.rect_contains_point(z.rect, e.pos.x, e.pos.y))
          end
        }
      }
    }
  }
}

