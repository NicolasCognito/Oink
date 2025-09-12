local function new_ruby(x, y, opts)
  opts = opts or {}
  local e = {
    pos = { x = x or 0, y = y or 0 },
    drawable = true,
    radius = opts.radius or 3,
    color = opts.color or {1.0, 0.2, 0.2, 1},
    collectable = { name = 'ruby', value = opts.value or 1 },
  }
  return e
end

return { new = new_ruby }

