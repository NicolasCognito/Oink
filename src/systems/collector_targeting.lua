local tiny = require('tiny')

local function dist2(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy
end

local function process(self, e, dt)
  if e.carrying and e.carrying ~= false then
    e.target_coin = nil
    return
  end
  -- Retain target if still valid
  if e.target_coin and e.target_coin.pos then return end
  -- Acquire nearest coin
  local ex, ey = e.pos.x, e.pos.y
  local best, bestd = nil, math.huge
  for _, ent in ipairs(self.world.entities) do
    if ent.coin and ent.pos then
      local d = dist2(ex, ey, ent.pos.x, ent.pos.y)
      if d < bestd then bestd, best = d, ent end
    end
  end
  e.target_coin = best
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('collector', 'pos')
  System.name = 'CollectorTargetingSystem'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
