local function new_agent(opts)
  opts = opts or {}
  return {
    pos = { x = opts.x or 0, y = opts.y or 0 },
    vel = { x = 0, y = 0 },
    speed = opts.speed or 60,
    radius = opts.radius or 6,
    drawable = opts.drawable ~= false,
    color = opts.color,
    label = opts.label,
  }
end

return { new = new_agent }

