local move = require('ai.movement')
local Inventory = require('inventory')

local function rect_contains(r, x, y)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function nearest_coin(ctx, e)
  local best, bestd2
  local coins = ctx.coins or {}
  for i = 1, #coins do
    local c = coins[i]
    local d2 = move.dist2(e.pos, c.pos)
    if not best or d2 < bestd2 then best, bestd2 = c, d2 end
  end
  return best
end

local function nearest_vault(ctx, e)
  local zones = ctx.zones or {}
  local best, bestd2
  for i = 1, #zones do
    local z = zones[i]
    if z and z.collector and z.inventory and z.rect then
      local cx, cy = z.rect.x + z.rect.w/2, z.rect.y + z.rect.h/2
      local d2 = move.dist2(e.pos, { x = cx, y = cy })
      if not best or d2 < bestd2 then best, bestd2 = z, d2 end
    end
  end
  return best
end

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
            return e.inventory and not Inventory.isFull(e.inventory) and ctx.coins and #ctx.coins > 0
          end
        },
        {
          to = 'go_to_vault',
          when = function(e, ctx)
            return e.inventory and Inventory.isFull(e.inventory) and nearest_vault(ctx, e) ~= nil
          end
        }
      }
    },
    seek_coin = {
      update = function(e, ctx)
        if not ctx.coins or #ctx.coins == 0 then e.vel.x, e.vel.y = 0, 0; return end
        local coin = nearest_coin(ctx, e)
        if not coin then e.vel.x, e.vel.y = 0, 0; return end
        e.vel.x, e.vel.y = move.seek(e.pos, coin.pos, e.speed or 0)
      end,
      transitions = {
        {
          to = 'go_to_vault',
          when = function(e, ctx)
            return e.inventory and Inventory.isFull(e.inventory) and nearest_vault(ctx, e) ~= nil
          end
        },
        {
          to = 'idle',
          when = function(e, ctx)
            return not ctx.coins or #ctx.coins == 0
          end
        }
      }
    },
    go_to_vault = {
      update = function(e, ctx)
        local v = nearest_vault(ctx, e)
        e._vault_target = v
        if not v then e.vel.x, e.vel.y = 0, 0; return end
        local cx, cy = v.rect.x + v.rect.w/2, v.rect.y + v.rect.h/2
        e.vel.x, e.vel.y = move.seek(e.pos, {x=cx, y=cy}, e.speed or 0)
      end,
      transitions = {
        {
          to = 'deposit',
          when = function(e, ctx)
            local v = e._vault_target or nearest_vault(ctx, e)
            return v and rect_contains(v.rect, e.pos.x, e.pos.y)
          end
        },
        {
          to = 'idle',
          when = function(e, ctx)
            return not e.inventory or not Inventory.isFull(e.inventory)
          end
        }
      }
    },
    deposit = {
      enter = function(e) e.vel.x, e.vel.y = 0, 0 end,
      update = function(e, ctx)
        local v = e._vault_target or nearest_vault(ctx, e)
        if not v or not v.inventory then return end
        -- Transfer only coins by default using tuned transfer
        Inventory.transfer(e.inventory, v.inventory, { names = {'coin'} })
      end,
      transitions = {
        {
          to = 'idle',
          when = function(e, ctx)
            return e.inventory and e.inventory.count == 0
          end
        }
      }
    }
  }
}
