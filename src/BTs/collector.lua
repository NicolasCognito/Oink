local bt = require('tiny-bt-tasks')
local C = require('config')

local M = {}

function M.build()
  local T = bt.dsl
  local pickup_r = C.collector.pickup_radius or 8
  return bt.build(
    T.parallel({
      -- Continuous finder: populate owner.target with nearest uncontested coin
      T.task({
        task_type = 'find', find = true, claim = true, store = 'target',
        query = function(world, owner)
          local list, n = {}, 0
          for i = 1, #world.entities do
            local e = world.entities[i]
            if e and e.coin and e.pos and not e._dead and (not e.claimed_by or e.claimed_by == owner) then
              n = n + 1; list[n] = e
            end
          end
          return list
        end,
        score = function(owner, e)
          local dx, dy = e.pos.x - owner.pos.x, e.pos.y - owner.pos.y
          return dx*dx + dy*dy
        end,
      }),
      -- Actuation sequence: move toward current target, then pick it up
      T.sequence({
        T.task({ task_type = 'move_to', move_to = true, use_owner_target = true, radius = pickup_r, speed = 140 }),
        T.task({ task_type = 'pickup', pickup = true }),
      })
    }, { success = 1 })
  )
end

return M
