local move = require('ai.movement')
local Inventory = require('inventory')

return {
  initial = 'normal',
  states = {
    normal = {
      enter = function(e)
        e._suspend_work = false
        -- restore speed if coming from hungry
        if e._orig_speed then e.speed = e._orig_speed end
        -- restore collector/accept if previously overridden
        if e._prev_collector ~= nil then e.collector = e._prev_collector end
        if e._prev_accept ~= nil then e.accept_collectable = e._prev_accept end
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        local mode = e._activity_mode or 'working'
        local rate = (mode == 'working') and (e.hunger_rate_work or 1.0) or (e.hunger_rate_rest or 0.4)
        e.hunger = (e.hunger or 0) + rate * dt
      end,
      transitions = {
        {
          to = 'hungry',
          when = function(e)
            return (e.hunger or 0) >= (e.hunger_max or 6)
          end
        }
      }
    },
    hungry = {
      enter = function(e)
        -- Flag to pause other activities
        e._suspend_work = true
        -- Collector override to accept only food
        e._prev_collector = e._prev_collector == nil and e.collector or e._prev_collector
        e._prev_accept = e._prev_accept or e.accept_collectable
        e.collector = true
        if not e.inventory then e.inventory = Inventory.new(3) end
        e.accept_collectable = function(self, item)
          return item and item.food ~= nil
        end
        -- Speed penalty
        e._orig_speed = e._orig_speed or e.speed
        e.speed = (e._orig_speed or e.speed) * (e.hungry_speed_multiplier or 0.6)
      end,
      update = function(e, ctx, dt)
        dt = dt or 0
        local items = ctx.collectables or {}
        -- Seek nearest food
        local best, bestd
        for i = 1, #items do
          local it = items[i]
          if it and it.food and it.pos and e.pos then
            local d2 = move.dist2(e.pos, it.pos)
            if not best or d2 < bestd then best, bestd = it, d2 end
          end
        end
        if best and best.pos then
          e.vel.x, e.vel.y = move.seek(e.pos, best.pos, e.speed or 0)
        else
          e.vel.x, e.vel.y = 0, 0
        end
        -- Consume one food from inventory if present
        local inv = e.inventory
        if inv and inv.items then
          for idx, s in pairs(inv.slots or {}) do
            if s and s.name == 'egg' and (s.count or 0) > 0 then
              local removed = Inventory.remove_one(inv, idx)
              if removed then
                e.hunger = math.max(0, (e.hunger or 0) - (e.satiate_per_food or 4))
              end
              break
            end
          end
        end
        -- Hunger can still rise a bit while searching
        e.hunger = (e.hunger or 0) + (e.hunger_rate_rest or 0.4) * dt
      end,
      transitions = {
        {
          to = 'normal',
          when = function(e)
            return (e.hunger or 0) <= (e.hunger_min or 2)
          end,
          effect = function(e)
            -- Clear override
            e._suspend_work = false
          end
        }
      }
    }
  }
}

