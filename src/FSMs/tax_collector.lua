local move = require('ai.movement')
local Inventory = require('inventory')

return {
  initial = 'idle',
  states = {
    idle = {
      enter = function(e) e.vel.x, e.vel.y = 0, 0 end,
      update = function(e) e.vel.x, e.vel.y = 0, 0 end,
      transitions = {
        {
          to = 'seek_coin',
          when = function(e, ctx)
            if not e.inventory or Inventory.isFull(e.inventory) then return false end
            return ctx.coins and #ctx.coins > 0
          end
        }
      }
    },
    seek_coin = {
      update = function(e, ctx)
        if not ctx.coins or #ctx.coins == 0 then e.vel.x, e.vel.y = 0, 0; return end
        -- find nearest coin
        local best, bestd2
        for i = 1, #ctx.coins do
          local c = ctx.coins[i]
          local d2 = move.dist2(e.pos, c.pos)
          if not best or d2 < bestd2 then best, bestd2 = c, d2 end
        end
        e.vel.x, e.vel.y = move.seek(e.pos, best.pos, e.speed or 0)
      end,
      transitions = {
        {
          to = 'idle',
          when = function(e, ctx)
            return (not ctx.coins or #ctx.coins == 0) or (e.inventory and Inventory.isFull(e.inventory))
          end
        }
      }
    }
  }
}

