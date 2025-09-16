local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local C = require('config')

local function get_target_pos(task)
  local t = task.target
  if t then
    if type(t.x) == 'number' and type(t.y) == 'number' then
      return t.x, t.y
    end
    if t.pos and type(t.pos.x) == 'number' then
      return t.pos.x, t.pos.y
    end
  end
  -- Special: follow owner's target_coin if present
  local owner = task.owner
  if owner and owner.target_coin and owner.target_coin.pos then
    return owner.target_coin.pos.x, owner.target_coin.pos.y
  end
  return nil, nil
end

local function process(self, task, dt)
  if task.task_type ~= 'move' then return end
  if task.task_cancelled then task.task_complete = true; task.task_result = bt.FAILURE; return end
  local owner = task.owner
  if not owner or not owner.pos then task.task_complete = true; task.task_result = bt.FAILURE; return end
  local tx, ty = get_target_pos(task)
  if not tx then task.task_complete = true; task.task_result = bt.FAILURE; return end

  local dx, dy = tx - owner.pos.x, ty - owner.pos.y
  local d2 = dx * dx + dy * dy
  local rad = C.collector.pickup_radius
  if d2 <= rad * rad then
    task.task_complete = true
    task.task_result = bt.SUCCESS
    return
  end
  local d = math.sqrt(d2)
  local spd = task.speed or (owner.collector and owner.collector.speed) or C.collector.base_speed
  local step = spd * dt
  owner.pos.x = owner.pos.x + (dx / d) * step
  owner.pos.y = owner.pos.y + (dy / d) * step
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'task_type')
  System.name = 'MoveTaskSystem'
  System.process = function(self, task, dt) return process(self, task, dt) end
  return System
end
