local move = require('ai.movement')
local Coll = require('collision')
local spawn = require('spawn')
local WorkToken = require('components.work_token')

local function find_nearest_token_mine(ctx, e)
  local zones = ctx.zones or {}
  local best, bestd
  for i = 1, #zones do
    local z = zones[i]
    if z and z.type == 'token_mine' and z.rect and e.pos then
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
        e._work_timer = 0
      end,
      update = function(e, ctx, dt)
        local target = e._mine_target or find_nearest_token_mine(ctx, e)
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
        e._work_timer = 0
      end,
      update = function(e, ctx, dt)
        -- Stay roughly in place while working
        e.vel.x, e.vel.y = 0, 0
        -- Drop work tokens at a fixed interval
        local interval = e.work_drop_interval or 0.6
        e._work_timer = (e._work_timer or 0) + (dt or 0)
        while e._work_timer >= interval do
          e._work_timer = e._work_timer - interval
          local r = (e.work_drop_radius or 6)
          local ang = math.random() * math.pi * 2
          local d = math.random() * r
          local x = e.pos.x + math.cos(ang) * d
          local y = e.pos.y + math.sin(ang) * d
          spawn.request(WorkToken.new(x, y, { ttl = e.work_token_ttl or 2.0, value = 1 }))
        end
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

