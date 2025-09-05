local function new_egg(x, y, opts)
  opts = opts or {}
  return {
    pos = { x = x or 0, y = y or 0 },
    drawable = true,
    radius = opts.radius or 3,
    color = opts.color or {1.0, 0.95, 0.7, 1},
    collectable = { name = 'egg', value = opts.value or 1 },
    -- Mark eggs as food so generic eaters can find/accept them
    food = { nutrition = opts.nutrition or 4 },
    expire_ttl = opts.ttl or 15,
    expire_age = 0,
  }
end

return { new = new_egg }
