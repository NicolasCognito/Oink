local function new_work_token(x, y, opts)
  opts = opts or {}
  return {
    pos = { x = x or 0, y = y or 0 },
    drawable = true,
    radius = opts.radius or 2.5,
    color = opts.color or {0.3, 0.8, 1.0, 1},
    collectable = { name = 'work', value = opts.value or 1 },
    -- Short lived by design
    expire_ttl = opts.ttl or 3.0,
    expire_age = 0,
  }
end

return { new = new_work_token }

