local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local R = require('systems.task_util')

local function norm(dx, dy)
  local len = math.sqrt(dx * dx + dy * dy)
  if len <= 0 then return 0, 0, 0 end
  return dx / len, dy / len, len
end

local function process(self, task, dt)
  if task.task_complete or task.task_cancelled then
    if task.task_cancelled and not task.task_complete then
      task.task_complete = true
      task.task_result = bt.FAILURE
    end
    return
  end
  local owner = task.bt_owner
  if not owner or not owner.pos or not owner.vel then
    task.task_complete = true
    task.task_result = bt.FAILURE
    return
  end

  local spec = {
    target = { fallback_paths = { 'owner.target.pos' } },
    speed  = { fallback_paths = { 'owner.speed' }, default = 100 },
    radius = { default = 6 },
  }
  local p = R.resolve(task, owner, self.world, spec)
  local target = p.target
  if type(target) == 'function' then target = target(owner, task, self.world) end

  local tx, ty
  if type(target) == 'table' and target.x and target.y then
    tx, ty = target.x, target.y
  elseif type(target) == 'table' and target.pos and target.pos.x and target.pos.y then
    tx, ty = target.pos.x, target.pos.y
  end
  if not tx or not ty then
    task.task_complete = true
    task.task_result = bt.FAILURE
    return
  end

  local dx, dy = tx - owner.pos.x, ty - owner.pos.y
  local ux, uy, dist = norm(dx, dy)
  local r = p.radius or 0
  if dist <= r then
    owner.vel.x, owner.vel.y = 0, 0
    task.task_complete = true
    task.task_result = bt.SUCCESS
    return
  end
  local spd = p.speed or 100
  owner.vel.x = ux * spd
  owner.vel.y = uy * spd
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'chase')
  System.name = 'Task_Chase'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end

