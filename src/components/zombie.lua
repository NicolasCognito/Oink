local function new_zombie(opts)
  opts = opts or {}
  local e = {
    pos = { x = opts.x or 260, y = opts.y or 120 },
    vel = { x = 0, y = 0 },
    radius = opts.radius or 6,
    speed = opts.speed or 60,
    drawable = true,
    zombie = true,
    color = opts.color or {0.3, 0.9, 0.3, 1},
    label = opts.label or 'Zombie',
  }
  return e
end

return { new = new_zombie }

