local move = require('ai.movement')
local Inventory = require('inventory')

local function rect_contains(r, x, y)
  return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Find all tax collectors in context
local function get_other_collectors(ctx, self_entity)
  local collectors = {}
  local idx = 1
  local TaxFSM = require('FSMs.tax_collector')
  local agents = ctx.agents or {}
  for i = 1, #agents do
    local a = agents[i]
    if a and a ~= self_entity and a.brain and a.brain.fsm_def == TaxFSM then
      collectors[idx] = a
      idx = idx + 1
    end
  end
  return collectors
end

-- Score a coin based on distance and competition from other collectors
local function score_coin(coin, entity, other_collectors)
  if not coin or not coin.pos then return math.huge end

  local my_dist = move.dist2(entity.pos, coin.pos)
  local score = math.sqrt(my_dist)

  -- Check if another collector is already claiming this coin
  for i = 1, #other_collectors do
    local other = other_collectors[i]
    if other._claimed_coin == coin then
      return math.huge -- Skip claimed coins
    end
  end

  -- Factor in competition - reduce score if others are closer
  local competition_penalty = 0
  for i = 1, #other_collectors do
    local other = other_collectors[i]
    if other and other.pos then
      local other_dist = move.dist2(other.pos, coin.pos)
      if other_dist < my_dist then
        -- Another collector is closer, penalize this coin
        competition_penalty = competition_penalty + 20 / (1 + math.sqrt(other_dist))
      end
    end
  end

  return score + competition_penalty
end

-- Find best coin to pursue considering swarm coordination
local function find_best_coin(ctx, entity)
  local coins = ctx.coins or {}
  if #coins == 0 then return nil end

  local other_collectors = get_other_collectors(ctx, entity)
  local best_coin, best_score = nil, math.huge

  for i = 1, #coins do
    local coin = coins[i]
    local score = score_coin(coin, entity, other_collectors)
    if score < best_score then
      best_score = score
      best_coin = coin
    end
  end

  return best_coin
end

-- Find vault with least congestion
local function find_best_vault(ctx, entity)
  local zones = ctx.zones or {}
  local vaults = {}
  local vi = 1

  -- Collect all vaults
  for i = 1, #zones do
    local z = zones[i]
    if z and z.collector and z.inventory and z.rect then
      vaults[vi] = z
      vi = vi + 1
    end
  end

  if #vaults == 0 then return nil end
  if #vaults == 1 then return vaults[1] end

  -- Score vaults based on distance and congestion
  local best_vault, best_score = nil, math.huge
  local other_collectors = get_other_collectors(ctx, entity)

  for i = 1, #vaults do
    local vault = vaults[i]
    local cx, cy = vault.rect.x + vault.rect.w/2, vault.rect.y + vault.rect.h/2
    local dist = math.sqrt(move.dist2(entity.pos, {x=cx, y=cy}))

    -- Count how many collectors are heading to this vault
    local congestion = 0
    for j = 1, #other_collectors do
      local other = other_collectors[j]
      if other._vault_target == vault then
        congestion = congestion + 1
      end
    end

    -- Score: distance + heavy penalty for congestion
    local score = dist + congestion * 50

    if score < best_score then
      best_score = score
      best_vault = vault
    end
  end

  return best_vault
end

-- Release any claimed resources
local function release_claims(entity)
  entity._claimed_coin = nil
  entity._vault_target = nil
end

return {
  initial = 'idle',
  states = {
    idle = {
      enter = function(e) 
        e.vel.x, e.vel.y = 0, 0
        release_claims(e)
        e._idle_timer = 0
      end,
      update = function(e, ctx, dt) 
        e.vel.x, e.vel.y = 0, 0
        -- Brief pause to prevent oscillation
        e._idle_timer = (e._idle_timer or 0) + (dt or 0)
      end,
      transitions = {
        {
          to = 'seek_coin',
          when = function(e, ctx)
            if e._idle_timer and e._idle_timer < 0.1 then return false end
            return e.inventory and not Inventory.isFull(e.inventory) and 
                   ctx.coins and #ctx.coins > 0
          end
        },
        {
          to = 'go_to_vault',
          when = function(e, ctx)
            if e._idle_timer and e._idle_timer < 0.1 then return false end
            return e.inventory and Inventory.isFull(e.inventory) and 
                   find_best_vault(ctx, e) ~= nil
          end
        }
      }
    },

    seek_coin = {
      enter = function(e, ctx)
        -- Claim the best available coin
        local coin = find_best_coin(ctx, e)
        e._claimed_coin = coin
        e._recalc_timer = 0
      end,
      update = function(e, ctx, dt)
        -- Periodically recalculate target for better swarm adaptation
        e._recalc_timer = (e._recalc_timer or 0) + (dt or 0)
        if e._recalc_timer > 0.5 then
          e._recalc_timer = 0
          local better_coin = find_best_coin(ctx, e)
          if better_coin and better_coin ~= e._claimed_coin then
            e._claimed_coin = better_coin
          end
        end

        -- Validate claimed coin still exists
        if e._claimed_coin then
          local still_exists = false
          for i = 1, #(ctx.coins or {}) do
            if ctx.coins[i] == e._claimed_coin then
              still_exists = true
              break
            end
          end
          if not still_exists then
            e._claimed_coin = find_best_coin(ctx, e)
          end
        else
          e._claimed_coin = find_best_coin(ctx, e)
        end

        -- Move toward claimed coin
        if e._claimed_coin and e._claimed_coin.pos then
          e.vel.x, e.vel.y = move.seek(e.pos, e._claimed_coin.pos, e.speed or 0)
        else
          e.vel.x, e.vel.y = 0, 0
        end
      end,
      exit = function(e)
        e._claimed_coin = nil
      end,
      transitions = {
        {
          to = 'go_to_vault',
          when = function(e, ctx)
            return e.inventory and Inventory.isFull(e.inventory) and 
                   find_best_vault(ctx, e) ~= nil
          end
        },
        {
          to = 'idle',
          when = function(e, ctx)
            return not ctx.coins or #ctx.coins == 0 or not e._claimed_coin
          end
        }
      }
    },

    go_to_vault = {
      enter = function(e, ctx)
        e._vault_target = find_best_vault(ctx, e)
      end,
      update = function(e, ctx, dt)
        -- Validate vault still exists and pick new one if needed
        if not e._vault_target then
          e._vault_target = find_best_vault(ctx, e)
        end

        if not e._vault_target then 
          e.vel.x, e.vel.y = 0, 0
          return 
        end

        local cx = e._vault_target.rect.x + e._vault_target.rect.w/2
        local cy = e._vault_target.rect.y + e._vault_target.rect.h/2
        e.vel.x, e.vel.y = move.seek(e.pos, {x=cx, y=cy}, e.speed or 0)
      end,
      exit = function(e)
        e._vault_target = nil
      end,
      transitions = {
        {
          to = 'deposit',
          when = function(e, ctx)
            local v = e._vault_target
            return v and rect_contains(v.rect, e.pos.x, e.pos.y)
          end
        },
        {
          to = 'idle',
          when = function(e, ctx)
            return not e.inventory or not Inventory.isFull(e.inventory) or 
                   not e._vault_target
          end
        }
      }
    },

    deposit = {
      enter = function(e) 
        e.vel.x, e.vel.y = 0, 0
        e._deposit_timer = 0
      end,
      update = function(e, ctx, dt)
        e._deposit_timer = (e._deposit_timer or 0) + (dt or 0)

        -- Small delay makes deposits feel more natural
        if e._deposit_timer > 0.2 then
          local v = e._vault_target or find_best_vault(ctx, e)
          if v and v.inventory then
            Inventory.transfer(e.inventory, v.inventory, { names = {'coin'} })
          end
        end
      end,
      exit = function(e)
        release_claims(e)
      end,
      transitions = {
        {
          to = 'idle',
          when = function(e, ctx)
            return not e.inventory or e.inventory.count == 0
          end
        }
      }
    }
  }
}