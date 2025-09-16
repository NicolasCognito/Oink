local tiny = require('tiny')
local C = require('config')

local function clamp(x, a, b) if x<a then return a elseif x>b then return b else return x end end

local function nearest_coin(self, e, radius)
  local best, bestd2
  local r2 = radius * radius
  for i=1,#self.world.entities do
    local c = self.world.entities[i]
    if c and c.coin and c.pos and not c._dead then
      local dx, dy = c.pos.x - e.pos.x, c.pos.y - e.pos.y
      local d2 = dx*dx + dy*dy
      if d2 <= r2 and (not bestd2 or d2 < bestd2) then best, bestd2 = c, d2 end
    end
  end
  return best, bestd2
end

local function process(self, e, dt)
  local w = e.wander or { speed = 80, dirx = 0, diry = 0, t = 0 }
  e.wander = w
  w.t = w.t - dt
  if w.t <= 0 then
    -- Bias direction toward nearest coin if sensed
    local sensed = e.sense_radius or 120
    local target = nearest_coin(self, e, sensed)
    if target and math.random() < 0.7 then
      local dx, dy = target.pos.x - e.pos.x, target.pos.y - e.pos.y
      local len = math.sqrt(dx*dx + dy*dy)
      if len > 0 then w.dirx, w.diry = dx/len, dy/len else w.dirx, w.diry = 0, 0 end
    else
      local ang = math.random() * math.pi * 2
      w.dirx, w.diry = math.cos(ang), math.sin(ang)
    end
    w.t = 0.5 + math.random() * 1.5
  end
  local step = (w.speed or 80) * dt
  e.pos.x = e.pos.x + w.dirx * step
  e.pos.y = e.pos.y + w.diry * step

  -- keep in bounds
  local area = C.spawner.area or {x_min=0,x_max=800,y_min=0,y_max=600}
  e.pos.x = clamp(e.pos.x, area.x_min, area.x_max)
  e.pos.y = clamp(e.pos.y, area.y_min, area.y_max)

  -- opportunistic coin steal
  local steal_r = e.steal_radius or 18
  local r2 = steal_r * steal_r
  for i=1,#self.world.entities do
    local coin = self.world.entities[i]
    if coin and coin.coin and coin.pos and not coin._dead then
      local dx, dy = coin.pos.x - e.pos.x, coin.pos.y - e.pos.y
      if dx*dx + dy*dy <= r2 then
        if e.always_pick or math.random() < (e.steal_chance or 0.5) then
          coin._dead = true
          self.world:removeEntity(coin)
          break
        end
      end
    end
  end
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('fool','pos')
  System.name = 'FoolSystem'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end
