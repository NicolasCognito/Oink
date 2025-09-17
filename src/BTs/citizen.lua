local bt = require('tiny-bt')

local M = {}

local function away_target(owner, threat, dist)
  if not (owner and owner.pos and threat and threat.pos) then return nil end
  local dx, dy = owner.pos.x - threat.pos.x, owner.pos.y - threat.pos.y
  local len = math.sqrt(dx*dx + dy*dy)
  if len <= 0 then return { x = owner.pos.x, y = owner.pos.y } end
  local ux, uy = dx/len, dy/len
  return { x = owner.pos.x + ux * dist, y = owner.pos.y + uy * dist }
end

function M.build(opts)
  local T = bt.dsl
  local sense = (opts and opts.sense_radius) or 260
  local flee_dist = (opts and opts.flee_distance) or 140
  local hysteresis = (opts and opts.hysteresis) or 40
  local enter_dist = flee_dist
  local exit_dist = flee_dist + hysteresis
  local flee_speed = (opts and opts.flee_speed) or 140
  local prof = (opts and opts.profession) or 'collector'

  local function profession_tree(owner)
    if owner._profession_tree then return owner._profession_tree end
    local p = owner.profession or prof
    if p == 'collector' then
      local Collector = require('BTs.collector')
      owner._profession_tree = Collector.build()
    else
      owner._profession_tree = bt.build(T.task({ task_type = 'halt', halt = true }))
    end
    return owner._profession_tree
  end

  return bt.build(
    T.parallel({
      -- Track nearest zombie as threat
      T.action(function(ctx, dt)
        local w, o = ctx.world, ctx.entity
        local best, bestd
        for i=1,#w.entities do
          local e = w.entities[i]
          if e and e.zombie and e.pos and not e._dead then
            local dx,dy = e.pos.x-o.pos.x, e.pos.y-o.pos.y
            local d = dx*dx+dy*dy
            if d <= sense*sense and (not bestd or d<bestd) then bestd, best = d, e end
          end
        end
        o.threat = best
        return bt.RUNNING
      end),
      -- If threat within flee distance -> flee; else work subtree
      T.selector({
        T.sequence({
          T.condition(function(ctx)
            local o, th = ctx.entity, ctx.entity.threat
            if not (o and o.pos and th and th.pos) then o._fleeing = false; return false end
            local dx,dy = o.pos.x-th.pos.x, o.pos.y-th.pos.y
            local d2 = dx*dx+dy*dy
            if o._fleeing then
              return d2 < (exit_dist * exit_dist)
            else
              return d2 < (enter_dist * enter_dist)
            end
          end),
          T.action({
            start = function(ctx)
              ctx.entity._fleeing = true
            end,
            tick = function(ctx, dt)
              local o, th = ctx.entity, ctx.entity.threat
              if not (o and o.pos and o.vel and th and th.pos) then o._fleeing=false; return bt.FAILURE end
              local dx,dy = o.pos.x - th.pos.x, o.pos.y - th.pos.y
              local d = math.sqrt(dx*dx+dy*dy)
              if d >= exit_dist then o.vel.x,o.vel.y=0,0; o._fleeing=false; return bt.FAILURE end
              if d <= 0 then o.vel.x,o.vel.y=0,0; return bt.RUNNING end
              local ux,uy = dx/d, dy/d
              local spd = o.speed or flee_speed
              o.vel.x, o.vel.y = ux*spd, uy*spd
              return bt.RUNNING
            end,
            abort = function(ctx)
              ctx.entity._fleeing = false
            end
          })
        }),
        T.subtree(function(owner) return profession_tree(owner) end)
      })
    }, { success = 2 })
  )
end

return M
