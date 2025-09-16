local bt = require('tiny-bt-tasks')
local C = require('config')

local M = {}

-- Conditions
bt.register_condition('has_payload', function(owner)
  return owner.carrying and owner.carrying ~= false
end)

bt.register_condition('has_target_coin', function(owner)
  return owner.target_coin ~= nil
end)

-- Tasks: move, pickup_coin, deposit
bt.register_task('move', {
  validate = function(owner, p)
    return owner and owner.pos and p and p.target ~= nil
  end,
  spawn = function(owner, world, p)
    local e = {
      bt_task = true,
      task_type = 'move',
      owner = owner,
      target = p.target, -- can be {x,y} or an entity with .pos
      speed = p.speed,
    }
    world:addEntity(e)
    return e
  end,
})

bt.register_task('pickup_coin', {
  validate = function(owner, p)
    return owner and owner.pos
  end,
  spawn = function(owner, world, p)
    local e = {
      bt_task = true,
      task_type = 'pickup',
      owner = owner,
      coin = p and p.coin or nil,
    }
    world:addEntity(e)
    return e
  end,
})

bt.register_task('deposit_at_vault', {
  validate = function(owner, p)
    return owner and owner.pos and p and p.vault
  end,
  spawn = function(owner, world, p)
    local e = {
      bt_task = true,
      task_type = 'deposit',
      owner = owner,
      vault = p.vault,
    }
    world:addEntity(e)
    return e
  end,
})

-- Build and attach a simple collector tree
function M.attach_collector_bt(collector, vault)
  local T = bt.dsl
  local tree = bt.build(
    T.selector{
      -- If carrying, go to vault and deposit
      T.sequence{
        T.condition('has_payload'),
        T.task('move', { target = vault.pos }),
        T.task('deposit_at_vault', { vault = vault }),
      },
      -- Else if we have a target coin, move and pick it up
      T.sequence{
        T.condition('has_target_coin'),
        T.task('move', { target = collector }), -- move toward dynamic target via owner.target_coin in system
        T.task('pickup_coin', { coin = collector }),
      },
      -- Fallback: idle near vault (small nudge)
      T.task('move', { target = vault.pos }),
    }
  )
  collector.bt = bt.instance(tree, { tick_interval = 0.05, name = 'CollectorBT' })
end

return M
