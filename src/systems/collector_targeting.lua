local tiny = require('tiny')

local function dist2(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy
end

local function in_world(self, ent)
  if not ent then return false end
  -- membership test by scanning indices; small worlds make this OK
  for i = 1, #self.world.entities do
    if self.world.entities[i] == ent then return true end
  end
  return false
end

local function release_claim(e)
  if e.target_coin and e.target_coin.claimed_by == e then
    e.target_coin.claimed_by = nil
  end
end

local function process(self, e, dt)
  if e.carrying and e.carrying ~= false then
    release_claim(e)
    e.target_coin = nil
    return
  end
  -- Retain target if still valid
  if e.target_coin and e.target_coin.pos and not e.target_coin._dead and in_world(self, e.target_coin) then return end
  release_claim(e)
  -- Acquire nearest coin
  local ex, ey = e.pos.x, e.pos.y
  local best, bestd = nil, math.huge
  for _, ent in ipairs(self.world.entities) do
    if ent.coin and ent.pos and not ent._dead and (not ent.claimed_by or ent.claimed_by == e) then
      local d = dist2(ex, ey, ent.pos.x, ent.pos.y)
      if d < bestd then bestd, best = d, ent end
    end
  end
  e.target_coin = best
  if best then best.claimed_by = e end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('collector', 'pos')
  System.name = 'CollectorTargetingSystem'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
