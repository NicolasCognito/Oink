local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local C = require('config')
local R = require('systems.task_util')

local function norm(dx, dy)
  local len = math.sqrt(dx * dx + dy * dy)
  if len <= 0 then return 0, 0, 0 end
  return dx / len, dy / len, len
end

local function process(self, task_e, dt)
  -- Params can come from node, owner, or functions; resolved uniformly
  if task_e.task_complete or task_e.task_cancelled then
    if task_e.task_cancelled and not task_e.task_complete then
      task_e.task_complete = true
      task_e.task_result = bt.FAILURE
    end
    return
  end

  local owner = task_e.bt_owner
  if not owner or not owner.pos or not owner.vel then
    task_e.task_complete = true
    task_e.task_result = bt.FAILURE
    return
  end

  local spec = {
    target = { fallback_paths = { 'owner.target.pos' } },
    speed  = { fallback_paths = { 'owner.speed', 'owner.collector.speed' }, default = (C.collector and C.collector.base_speed) or 100 },
    radius = { default = (C.collector and C.collector.pickup_radius) or 8 },
  }
  local p = R.resolve(task_e, owner, self.world, spec)
  local target = p.target
  if type(target) == 'function' then target = target(owner, task_e, self.world) end
  local tx, ty
  if type(target) == 'table' and target.x and target.y then
    tx, ty = target.x, target.y
  elseif type(target) == 'table' and target.pos and target.pos.x and target.pos.y then
    tx, ty = target.pos.x, target.pos.y
  end
  if not tx or not ty then
    task_e.task_complete = true
    task_e.task_result = bt.FAILURE
    return
  end

  local dx = tx - owner.pos.x
  local dy = ty - owner.pos.y
  local ux, uy, dist = norm(dx, dy)
  local r = p.radius or 4
  if dist <= r then
    owner.vel.x, owner.vel.y = 0, 0
    task_e.task_complete = true
    task_e.task_result = bt.SUCCESS
    return
  end

  local spd = p.speed or 100
  owner.vel.x = ux * spd
  owner.vel.y = uy * spd
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'move_to')
  System.name = 'Task_MoveTo'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
