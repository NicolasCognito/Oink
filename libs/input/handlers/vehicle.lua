return function(opts)
  opts = opts or {}
  local accel = opts.accel or 200
  local max_speed = opts.max_speed or 180
  local turn_rate = opts.turn_rate or (math.pi) -- radians per second at full turn
  local friction = opts.friction or 120
  return {
    channel = 'actor',
    kind = 'vehicle',
    on = function(self, who, ctx, input, dt)
      if not who or not who.pos or not who.vel then return end
      who._veh = who._veh or { speed = 0, heading = who.heading or 0 }
      local v = who._veh
      -- Accelerate with W
      if input.held('w') or input.held('up') then
        v.speed = math.min(max_speed, v.speed + accel * (dt or 0))
      else
        -- Friction when no throttle
        local dec = friction * (dt or 0)
        v.speed = (v.speed > dec) and (v.speed - dec) or 0
      end
      -- Turn with A/D based on current speed (turning always allowed)
      local t = 0
      if input.held('a') or input.held('left') then t = t - 1 end
      if input.held('d') or input.held('right') then t = t + 1 end
      if t ~= 0 then
        v.heading = v.heading + t * turn_rate * (dt or 0)
      end
      who.heading = v.heading
      -- Set velocity from heading and speed
      local cx, sy = math.cos(v.heading), math.sin(v.heading)
      who.vel.x = cx * v.speed
      who.vel.y = sy * v.speed
    end
  }
end
