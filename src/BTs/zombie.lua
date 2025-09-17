local bt = require('tiny-bt-tasks')

local M = {}

function M.build(opts)
  local T = bt.dsl
  local sense = (opts and opts.sense_radius) or 220
  local speed = (opts and opts.speed) or 110
  return bt.build(
    T.parallel({
      -- Continuous target acquisition: nearest 'living' within sense
      T.task({
        task_type = 'find', find = true, store = 'owner.target', claim = false,
        query = function(world, owner)
          local list, n = {}, 0
          for i = 1, #world.entities do
            local e = world.entities[i]
            if e and e.living and e.pos and not e._dead then
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
      -- Behavior: chase target if available, else halt (stop moving)
      T.selector({
        T.task({ task_type = 'chase', chase = true, target = 'owner.target.pos', speed = 'owner.speed' or speed, radius = 6 }),
        T.task({ task_type = 'halt', halt = true })
      })
    }, { success = 2, failure = 99999 })
  )
end

return M
