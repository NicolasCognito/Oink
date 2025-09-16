local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local C = require('config')

local function process(self, task, dt)
  if task.task_type ~= 'deposit' then return end
  if task.task_cancelled then task.task_complete = true; task.task_result = bt.FAILURE; return end
  local owner = task.owner
  local vault = task.vault
  if not owner or not owner.pos or not vault or not vault.pos then task.task_complete = true; task.task_result = bt.FAILURE; return end
  if not owner.carrying or owner.carrying == false then task.task_complete = true; task.task_result = bt.FAILURE; return end
  local dx, dy = vault.pos.x - owner.pos.x, vault.pos.y - owner.pos.y
  local d2 = dx * dx + dy * dy
  local rad = C.collector.deposit_radius
  if d2 <= rad * rad then
    vault.coin_count = (vault.coin_count or 0) + (owner.carrying.value or 1)
    owner.carrying = false
    task.task_complete = true
    task.task_result = bt.SUCCESS
  else
    task.task_complete = true
    task.task_result = bt.FAILURE
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'task_type')
  System.name = 'DepositTaskSystem'
  System.process = function(self, task, dt) return process(self, task, dt) end
  return System
end
