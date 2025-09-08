local M = {}

local lg = love and love.graphics

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi else return v end
end

function M.new(w, h, opts)
  w = w or 200; h = h or 140
  opts = opts or {}
  local self = {
    w = w, h = h,
    left = { y = h/2, h = 28, speed = 120 },
    right = { y = h/2, h = 28, speed = 110 },
    ball = { x = w/2, y = h/2, vx = 80, vy = 60, r = 3 },
    score = { l = 0, r = 0 },
    canvas = nil,
    _acc = 0,
    bridge = opts.bridge, -- optional two-way bridge
  }

  local function keydown(k)
    return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(k)
  end

  function self:update(dt, controls)
    dt = dt or 0
    -- Controls are polled directly from love.keyboard to avoid coupling
    local up = keydown('w') or keydown('up')
    local down = keydown('s') or keydown('down')
    -- Player paddle (left)
    if up then self.left.y = self.left.y - self.left.speed * dt end
    if down then self.left.y = self.left.y + self.left.speed * dt end
    self.left.y = clamp(self.left.y, self.left.h/2, self.h - self.left.h/2)

    -- Simple AI for right paddle
    local target = self.ball.y
    if math.abs(target - self.right.y) > 2 then
      local dir = (target > self.right.y) and 1 or -1
      self.right.y = self.right.y + dir * self.right.speed * dt
      self.right.y = clamp(self.right.y, self.right.h/2, self.h - self.right.h/2)
    end

    -- Ball
    local b = self.ball
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt
    -- Collide top/bottom
    if b.y - b.r <= 0 then b.y = b.r; b.vy = -b.vy end
    if b.y + b.r >= self.h then b.y = self.h - b.r; b.vy = -b.vy end
    -- Collide left paddle
    local lp_x, lp_y, lp_w, lp_h = 8, self.left.y - self.left.h/2, 4, self.left.h
    if b.x - b.r <= lp_x + lp_w and b.y >= lp_y and b.y <= lp_y + lp_h and b.vx < 0 then
      b.x = lp_x + lp_w + b.r
      b.vx = -b.vx * 1.05
      b.vy = b.vy + (b.y - (lp_y + lp_h/2)) * 2
    end
    -- Collide right paddle
    local rp_x, rp_y, rp_w, rp_h = self.w - 8 - 4, self.right.y - self.right.h/2, 4, self.right.h
    if b.x + b.r >= rp_x and b.y >= rp_y and b.y <= rp_y + rp_h and b.vx > 0 then
      b.x = rp_x - b.r
      b.vx = -b.vx * 1.05
      b.vy = b.vy + (b.y - (rp_y + rp_h/2)) * 2
    end
    -- Score
    if b.x < -10 then
      self.score.r = self.score.r + 1
      b.x, b.y, b.vx, b.vy = self.w/2, self.h/2, 80, 60
    elseif b.x > self.w + 10 then
      self.score.l = self.score.l + 1
      b.x, b.y, b.vx, b.vy = self.w/2, self.h/2, -80, -60
    end
  end

  function self:render()
    if not (lg and lg.newCanvas) then return end
    if not self.canvas or self.canvas:getWidth() ~= self.w or self.canvas:getHeight() ~= self.h then
      self.canvas = lg.newCanvas(self.w, self.h)
    end
    lg.push('all')
    local prev = lg.getCanvas and lg.getCanvas() or nil
    lg.setCanvas(self.canvas)
    lg.clear(0.05, 0.05, 0.08, 1)
    -- Mid line
    lg.setColor(0.7, 0.7, 0.8, 1)
    for y=0,self.h,8 do lg.rectangle('fill', self.w/2-1, y, 2, 4) end
    -- Paddles
    lg.rectangle('fill', 8, self.left.y - self.left.h/2, 4, self.left.h)
    lg.rectangle('fill', self.w-12, self.right.y - self.right.h/2, 4, self.right.h)
    -- Ball
    lg.circle('fill', self.ball.x, self.ball.y, self.ball.r)
    -- Score
    lg.print(tostring(self.score.l) .. ' - ' .. tostring(self.score.r), self.w/2 - 14, 4)
    -- Example: signal via bridge (optional hook point)
    -- if self.bridge and self.bridge.send then self.bridge.send('tick', { score = self.score }) end
    -- Restore
    lg.setCanvas(prev)
    lg.pop()
  end

  function self:draw(gfx, x, y, scale)
    if not (self.canvas and gfx and gfx.draw) then return end
    scale = scale or 2
    gfx.setColor(1,1,1,1)
    gfx.draw(self.canvas, x or 0, y or 0, 0, scale, scale)
  end

  return self
end

return M
