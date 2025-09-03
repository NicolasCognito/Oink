local function new_time_vortex(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'time_vortex',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 48 },
    label = opts.label or (opts.scale and ('Time x' .. tostring(opts.scale)) or 'Time Vortex'),
    drawable = true,
    scale = opts.scale or 2.0, -- time multiplier applied to affected entities
    affect_items = opts.affect_items or false,
    affected = {},
  }
end

local function contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function on_tick(zone, ctx)
  if zone.active == false then return end

  local agents = ctx.agents or {}
  local affected = zone.affected or {}
  zone.affected = affected

  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos then
      local inside = contains(zone.rect, a.pos.x, a.pos.y)
      local was_inside = affected[a]

      if inside and not was_inside then
        a._original_time_scale = a.time_scale or 1.0
        a.time_scale = zone.scale
        affected[a] = true
      elseif (not inside) and was_inside then
        a.time_scale = a._original_time_scale or 1.0
        a._original_time_scale = nil
        affected[a] = nil
      end
    end
  end

  if zone.affect_items then
    local items = ctx.collectables or {}
    for i = 1, #items do
      local it = items[i]
      if it and it.pos then
        if contains(zone.rect, it.pos.x, it.pos.y) then
          it.time_scale = zone.scale
        else
          it.time_scale = 1.0
        end
      end
    end
  end
end

return { new = new_time_vortex, on_tick = on_tick }

