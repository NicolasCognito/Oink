local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local C = require('config')
local R = require('systems.task_util')

local function process(self, task, dt)
  local owner = task.bt_owner
  if not owner or not owner.pos then
    task.task_complete = true
    task.task_result = bt.FAILURE
    return
  end
  local spec = {
    from = { fallback_paths = { 'owner.target' } },
    radius = { default = (C.collector and C.collector.pickup_radius) or 8 },
  }
  local p = R.resolve(task, owner, self.world, spec)
  local coin = p.from
  if not coin or not coin.pos or coin._dead then
    task.task_complete = true
    task.task_result = bt.FAILURE
    return
  end
  local dx, dy = coin.pos.x - owner.pos.x, coin.pos.y - owner.pos.y
  local r = p.radius or 8
  if (dx*dx + dy*dy) <= (r * r) then
    coin._dead = true
    if coin.claimed_by == owner then coin.claimed_by = nil end
    self.world:removeEntity(coin)
    owner.target = nil
    owner.carrying = (coin.coin and coin.coin.value) or 1
    task.task_complete = true
    task.task_result = bt.SUCCESS
  else
    -- not in range yet
    task.task_complete = true
    task.task_result = bt.FAILURE
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'pickup')
  System.name = 'Task_Pickup'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
