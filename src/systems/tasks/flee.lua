local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local R = require('systems.task_util')

local function norm(dx, dy)
  local len = math.sqrt(dx * dx + dy * dy)
  if len <= 0 then return 0, 0, 0 end
  return dx / len, dy / len, len
end

local function in_world(world, ent)
  if not ent then return false end
  for i=1,#world.entities do if world.entities[i] == ent then return true end end
  return false
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
    from      = { fallback_paths = { 'owner.threat' } },
    distance  = { default = 140 },
    speed     = { fallback_paths = { 'owner.speed' }, default = 140 },
    radius    = { default = 12 },
  }
  local p = R.resolve(task, owner, self.world, spec)
  local from = p.from
  if type(from) == 'function' then from = from(owner, task, self.world) end
  if not (from and from.pos) or from._dead or (not in_world(self.world, from)) then
    -- Clear stale threat reference
    owner.threat = nil
    -- No threat: indicate FAILURE so selector can try work branch
    task.task_complete = true
    task.task_result = bt.FAILURE
    return
  end
  local dx, dy = owner.pos.x - from.pos.x, owner.pos.y - from.pos.y
  local ux, uy, dist = norm(dx, dy)
  local desired = p.distance or 140
  if dist >= desired then
    owner.vel.x, owner.vel.y = 0, 0
    task.task_complete = true
    -- Safe already: signal FAILURE so selector can try work branch
    task.task_result = bt.FAILURE
    return
  end
  -- Move away toward a point at 'desired' distance
  local tx = owner.pos.x + ux * desired
  local ty = owner.pos.y + uy * desired
  local tdx, tdy = tx - owner.pos.x, ty - owner.pos.y
  local tux, tuy, _ = norm(tdx, tdy)
  local spd = p.speed or 140
  owner.vel.x = tux * spd
  owner.vel.y = tuy * spd
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'flee')
  System.name = 'Task_Flee'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
