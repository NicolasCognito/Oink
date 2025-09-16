local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local C = require('config')

local function process(self, task, dt)
  if task.task_type ~= 'pickup' then return end
  if task.task_cancelled then task.task_complete = true; task.task_result = bt.FAILURE; return end
  local owner = task.owner
  if not owner or not owner.pos then task.task_complete = true; task.task_result = bt.FAILURE; return end
  local coin = owner.target_coin
  if not coin or not coin.pos or coin._dead then task.task_complete = true; task.task_result = bt.FAILURE; return end

  local dx, dy = coin.pos.x - owner.pos.x, coin.pos.y - owner.pos.y
  local d2 = dx * dx + dy * dy
  local rad = C.collector.pickup_radius
  if d2 <= rad * rad then
    -- pick up: remove coin and set carrying
    owner.carrying = { value = (coin.coin and coin.coin.value) or 1 }
    coin._dead = true
    self.world:removeEntity(coin)
    task.task_complete = true
    task.task_result = bt.SUCCESS
  else
    -- not close enough: keep running; movement is handled by move task in tree
    task.task_complete = true
    task.task_result = bt.FAILURE
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'task_type')
  System.name = 'PickupTaskSystem'
  System.process = function(self, task, dt) return process(self, task, dt) end
  return System
end
