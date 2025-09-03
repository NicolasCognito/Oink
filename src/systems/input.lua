package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local tiny = require('tiny')
local ctx = require('ctx')

return function()
  local sys = tiny.system()
  sys.filter = tiny.requireAll('vel', 'controllable')
  sys._mode_cd = 0

  function sys:update(dt)
    local up    = love.keyboard.isDown('w') or love.keyboard.isDown('up')
    local down  = love.keyboard.isDown('s') or love.keyboard.isDown('down')
    local left  = love.keyboard.isDown('a') or love.keyboard.isDown('left')
    local right = love.keyboard.isDown('d') or love.keyboard.isDown('right')

    local ax = (right and 1 or 0) - (left and 1 or 0)
    local ay = (down and 1 or 0) - (up and 1 or 0)

    local mag = math.sqrt(ax*ax + ay*ay)
    for _, e in ipairs(self.entities) do
      local speed = e.speed or 120
      if mag > 0 then
        e.vel.x = (ax / mag) * speed
        e.vel.y = (ay / mag) * speed
      else
        e.vel.x = 0
        e.vel.y = 0
      end
    end

    -- Mode switching for zones: press Q/E while overlapping
    self._mode_cd = math.max(0, (self._mode_cd or 0) - (dt or 0))
    local want = 0
    if love.keyboard.isDown('q') then want = -1 end
    if love.keyboard.isDown('e') then want = 1 end
    if want ~= 0 and self._mode_cd == 0 then
      local snapshot = ctx.get(self.world, dt)
      -- For each controllable, check overlapping zones
      local entities = self.world.entities
      for _, p in ipairs(self.entities) do
        if p.pos then
          for i = 1, #entities do
            local z = entities[i]
            if z and z.zone and z.rect and z.on_mode_switch then
              local r = z.rect
              local px, py = p.pos.x, p.pos.y
              if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                -- Standardized signature: (zone, dir, ctx)
                z.on_mode_switch(z, want, snapshot)
              end
            end
          end
        end
      end
      self._mode_cd = 0.25
    end

    -- Zone-specific controls: allow zones to react to custom keys when player overlaps
    -- Simplify by picking the first overlapping zone with an `on_key` handler.
    self._zone_key_cd = math.max(0, (self._zone_key_cd or 0) - (dt or 0))
    if self._zone_key_cd == 0 then
      local snapshot = ctx.get(self.world, dt)
      local entities = self.world.entities
      for _, p in ipairs(self.entities) do
        if p.pos then
          local active = nil
          for i = 1, #entities do
            local z = entities[i]
            if z and z.zone and z.rect and z.on_key then
              local r = z.rect
              local px, py = p.pos.x, p.pos.y
              if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                active = z; break
              end
            end
          end
          p._active_zone = active
          if active then
            local pressed = nil
            if love.keyboard.isDown('m') then pressed = 'm' end
            if love.keyboard.isDown('t') then pressed = 't' end
            if love.keyboard.isDown('v') then pressed = 'v' end
            if love.keyboard.isDown('p') then pressed = 'p' end
            if pressed then
              active.on_key(active, p, pressed, snapshot)
              self._zone_key_cd = 0.2
              break -- one action per frame
            end
          end
        end
      end
    end
  end

  return sys
end
