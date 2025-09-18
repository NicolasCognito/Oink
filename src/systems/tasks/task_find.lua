local tiny = require('tiny')
local R = require('systems.task_util')

local function dist2(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy
end

local function in_world(world, ent)
  if not ent then return false end
  for i = 1, #world.entities do
    if world.entities[i] == ent then return true end
  end
  return false
end

local function process(self, task, dt)
  -- Long-running task: uses query->candidates and score to pick best; optional claim; never completes by default
  local owner = task.bt_owner
  if not owner or not owner.pos then return end

  -- Resolve params uniformly
  local spec = {
    query = {},
    score = {},
    store = { default = 'owner.target' },
    claim = { default = false },
  }
  local p = R.resolve(task, owner, self.world, spec)
  local store_path = p.store
  if type(store_path) == 'string' and not store_path:find('%.') then store_path = 'owner.' .. store_path end
  local current = R.read_path(owner, task, self.world, store_path)
  if current and (current._dead or (not in_world(self.world, current))) then
    if p.claim and current.claimed_by == owner then current.claimed_by = nil end
    R.set_path(owner, task, self.world, store_path, nil)
    current = nil
  end

  local query = p.query
  local score = p.score
  if type(query) ~= 'function' or type(score) ~= 'function' then return end

  local best, bestv
  local candidates = query(self.world, owner) or {}
  for i = 1, #candidates do
    local e = candidates[i]
    local v = score(owner, e)
    if type(v) == 'number' then
      if bestv == nil or v < bestv then best, bestv = e, v end
    end
  end

  if best and best ~= current then
    if p.claim then
      if current and current.claimed_by == owner then current.claimed_by = nil end
      best.claimed_by = owner
    end
    R.set_path(owner, task, self.world, store_path, best)
    if type(task.on_change) == 'function' then
      pcall(task.on_change, owner, current, best)
    end
  end
  -- Continuous by default; set task.complete_on_change=true or .complete_now=true to finish
  if task.complete_now or (task.complete_on_change and best and best ~= current) then
    task.task_complete = true
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('bt_task', 'find')
  System.name = 'task_find'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end

