local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local R = require('systems.task_util')

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'check')
  System.name = 'Task_Check'

  function System:process(task, dt)
    if task.task_complete then return end
    local owner = task.bt_owner
    local spec = { predicate = {} }
    local p = R.resolve(task, owner, self.world, spec)
    local pred = p.predicate
    local ok = false
    if type(pred) == 'function' then
      local okcall, res = pcall(pred, owner, task, self.world)
      ok = okcall and (res and true or false) or false
    else
      ok = pred and true or false
    end
    task.task_complete = true
    task.task_result = ok and bt.SUCCESS or bt.FAILURE
  end

  return System
end

