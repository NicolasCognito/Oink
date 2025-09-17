local bt = require('tiny-bt')

local M = {}

function M.build(opts)
  local T = bt.dsl
  local sense = (opts and opts.sense_radius) or 160
  local speed = (opts and opts.speed) or 90
  return bt.build(
    T.parallel({
      -- Update target to nearest living in sense radius
      T.action(function(ctx, dt)
        local world, owner = ctx.world, ctx.entity
        local best, bestd
        for i=1,#world.entities do
          local e = world.entities[i]
          if e and e.living and e.pos and not e._dead then
            local dx,dy = e.pos.x-owner.pos.x, e.pos.y-owner.pos.y
            local d = dx*dx+dy*dy
            if d <= sense*sense and (not bestd or d<bestd) then bestd, best = d, e end
          end
        end
        owner.target = best
        return bt.RUNNING
      end),
      -- chase else halt
      T.selector({
        T.action(function(ctx, dt)
          local o = ctx.entity; local t = o.target
          if not (o.pos and o.vel and t and t.pos) then return bt.FAILURE end
          local dx,dy = t.pos.x-o.pos.x, t.pos.y-o.pos.y
          local d2 = dx*dx+dy*dy
          if d2 <= 16 then o.vel.x,o.vel.y=0,0; return bt.SUCCESS end
          local d=math.sqrt(d2)
          local spd = o.speed or speed
          o.vel.x = dx/d*spd; o.vel.y = dy/d*spd
          return bt.RUNNING
        end),
        T.action(function(ctx) ctx.entity.vel.x,ctx.entity.vel.y=0,0; return bt.SUCCESS end)
      })
    }, { success = 2 })
  )
end

return M
