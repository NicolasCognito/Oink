local function new_home(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'home',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Home',
    drawable = true,
    -- Optional: local sleep tuning for citizens inside this zone
    sleep_rate_bonus = opts.sleep_rate_bonus or 0, -- additive to citizen.sleep_rate
  }
end

local function on_tick(zone, ctx, dt)
  -- Home is passive; sleeping handled by citizens
end

return { new = new_home, on_tick = on_tick }

