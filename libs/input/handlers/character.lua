local H = {}

return function(opts)
  opts = opts or {}
  local speed = opts.speed
  return {
    channel = 'actor',
    kind = 'character',
    on = function(self, who, ctx, input, dt)
      if not who or not who.vel then return end
      local ax, ay = input.axis.move()
      local nx, ny = input.axis.normalize(ax, ay)
      local s = speed or who.speed or 120
      who.vel.x = nx * s
      who.vel.y = ny * s
    end
  }
end
