local bt = require('tiny-bt-tasks')

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
      -- Continuous threat acquisition: nearest 'zombie' within sense
      T.task({
        task_type = 'find', find = true, store = 'owner.threat', claim = false,
        query = function(world, owner)
          local list, n = {}, 0
          for i = 1, #world.entities do
            local e = world.entities[i]
            if e and e.zombie and e.pos and not e._dead then
              local dx, dy = e.pos.x - owner.pos.x, e.pos.y - owner.pos.y
              if dx*dx + dy*dy <= sense * sense then
                n = n + 1; list[n] = e
              end
            end
          end
          return list
        end,
        score = function(owner, e)
          local dx, dy = e.pos.x - owner.pos.x, e.pos.y - owner.pos.y
          return dx*dx + dy*dy
        end,
      }),
      -- Behavior: if threat within flee distance -> flee; else work
      T.selector({
        T.sequence({
          T.task({ task_type = 'check', check = true, predicate = function(owner)
            local th = owner.threat
            if not (owner and owner.pos and th and th.pos) then return false end
            local dx, dy = owner.pos.x - th.pos.x, owner.pos.y - th.pos.y
            return (dx*dx + dy*dy) < (flee_dist * flee_dist)
          end }),
          T.task({ task_type = 'flee', flee = true, from = 'owner.threat', distance = flee_dist, speed = 'owner.speed' or flee_speed, radius = 12 })
        }),
        T.subtree(function(owner) return profession_tree(owner) end)
      })
    }, { success = 2, failure = 99999 })
  )
end

return M
