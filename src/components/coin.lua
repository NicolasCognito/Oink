local function new_coin(x, y, opts)
  opts = opts or {}
  local e = {
    pos = { x = x or 0, y = y or 0 },
    drawable = true,
    radius = opts.radius or 4,
    color = opts.color or {1, 0.85, 0.1, 1}, -- gold-ish
    coin = true,
  }
  return e
end

return {
  new = new_coin
}

