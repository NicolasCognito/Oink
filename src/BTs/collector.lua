local bt = require('tiny-bt')
local C = require('config')

local M = {}

function M.build()
  local T = bt.dsl
  local pickup_r = C.collector.pickup_radius or 8
  return bt.build(
    T.parallel({
      -- Finder: update owner.target each tick
      T.action(function(ctx, dt)
        local world, owner = ctx.world, ctx.entity
        local best, bestd
        for i=1,#world.entities do
          local e = world.entities[i]
          if e and e.coin and e.pos and not e._dead and (not e.claimed_by or e.claimed_by==owner) then
            local dx,dy = e.pos.x-owner.pos.x, e.pos.y-owner.pos.y
            local d = dx*dx+dy*dy
            if not bestd or d<bestd then bestd, best = d, e end
          end
        end
        if owner.target and owner.target ~= best and owner.target.claimed_by == owner then owner.target.claimed_by = nil end
        if best then best.claimed_by = owner; owner.target = best end
        return bt.RUNNING
      end),
      -- Move and pickup
      T.sequence({
        T.action(function(ctx, dt)
          local o = ctx.entity
          local t = o.target
          if not (o.pos and o.vel and t and t.pos and not t._dead) then return bt.FAILURE end
          local dx,dy = t.pos.x-o.pos.x, t.pos.y-o.pos.y
          local d2 = dx*dx+dy*dy
          if d2 <= pickup_r*pickup_r then
            o.vel.x, o.vel.y = 0,0
            return bt.SUCCESS
          end
          local d = math.sqrt(d2)
          local spd = o.speed or (C.collector.base_speed or 100)
          o.vel.x = dx/d * spd; o.vel.y = dy/d * spd
          return bt.RUNNING
        end),
        T.action(function(ctx, dt)
          local o = ctx.entity
          local t = o.target
          if not (t and t.pos) then return bt.FAILURE end
          local dx,dy = t.pos.x-o.pos.x, t.pos.y-o.pos.y
          if dx*dx+dy*dy <= pickup_r*pickup_r then
            t._dead = true
            ctx.world:removeEntity(t)
            if t.claimed_by == o then t.claimed_by = nil end
            o.target = nil
            o.carrying = (t.coin and t.coin.value) or 1
            return bt.SUCCESS
          end
          return bt.FAILURE
        end)
      })
    }, { success = 1 })
  )
end

return M
