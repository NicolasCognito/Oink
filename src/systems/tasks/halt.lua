local tiny = require('tiny')
local bt = require('tiny-bt-tasks')

local function process(self, task, dt)
  local owner = task.bt_owner
  if owner and owner.vel then owner.vel.x, owner.vel.y = 0, 0 end
  task.task_complete = true
  task.task_result = bt.SUCCESS
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'halt')
  System.name = 'Task_Halt'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end

