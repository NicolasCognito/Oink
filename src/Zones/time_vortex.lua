local function new_time_vortex(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'time_vortex',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 48 },
    label = opts.label or (opts.scale and ('Time x' .. tostring(opts.scale)) or 'Time Vortex'),
    drawable = true,
    scale = opts.scale or 2.0, -- time multiplier applied to affected entities
    affect_items = opts.affect_items or false,
    affect_zones = (opts.affect_zones ~= false),
    affected = {},
    -- optional modes: { {name='Stasis', scale=0.3}, {name='Haste', scale=2.5} }
    modes = opts.modes,
    mode_index = 1,
  }
  if z.modes and z.modes[1] then
    z.scale = z.modes[1].scale or z.scale
    local name = z.modes[1].name or ('x' .. tostring(z.scale))
    z.label = opts.label or ('Time: ' .. name)
  end
  return z
end

local Coll = require('collision')

local function on_tick(zone, ctx)
  if zone.active == false then return end

  local agents = ctx.agents or {}
  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos then
      local inside = Coll.rect_contains_point(zone.rect, a.pos.x, a.pos.y)
      a._time_scale_vortex = inside and zone.scale or 1.0
    end
  end

  if zone.affect_items then
    local items = ctx.collectables or {}
    for i = 1, #items do
      local it = items[i]
      if it and it.pos then
        if Coll.rect_contains_point(zone.rect, it.pos.x, it.pos.y) then
          it.time_scale = zone.scale
        else
          it.time_scale = 1.0
        end
      end
    end
  end

  -- Also affect other zones (default on)
  if zone.affect_zones then
    local zones = ctx.zones or {}
    for i = 1, #zones do
      local z = zones[i]
      if z and z ~= zone and z.rect then
        local zx, zy = Coll.rect_center(z.rect)
        local inside = Coll.rect_contains_point(zone.rect, zx, zy)
        z._time_scale_vortex = inside and zone.scale or 1.0
      end
    end
  end
end

-- Optional: support mode switching (Q/E while player overlaps handled by input system)
local function on_mode_switch(zone, ctx, dir)
  if not zone.modes or #zone.modes == 0 then return end
  local n = #zone.modes
  local idx = (zone.mode_index or 1) + (dir or 0)
  if idx < 1 then idx = n end
  if idx > n then idx = 1 end
  zone.mode_index = idx
  local mode = zone.modes[idx]
  zone.scale = mode.scale or zone.scale
  local name = mode.name or ('x' .. tostring(zone.scale))
  zone.label = 'Time: ' .. name

  -- Immediately apply new multiplier to entities/zones currently inside
  if ctx then
    local agents = ctx.agents or {}
    for i = 1, #agents do
      local a = agents[i]
      if a and a.pos and Coll.rect_contains_point(zone.rect, a.pos.x, a.pos.y) then
        a._time_scale_vortex = zone.scale
      end
    end
    if zone.affect_items then
      local items = ctx.collectables or {}
      for i = 1, #items do
        local it = items[i]
        if it and it.pos and Coll.rect_contains_point(zone.rect, it.pos.x, it.pos.y) then
          it._time_scale_vortex = zone.scale
        end
      end
    end
    if zone.affect_zones then
      local zones = ctx.zones or {}
      for i = 1, #zones do
        local z = zones[i]
        if z and z ~= zone and z.rect then
          local zx, zy = Coll.rect_center(z.rect)
          if Coll.rect_contains_point(zone.rect, zx, zy) then
            z._time_scale_vortex = zone.scale
          end
        end
      end
    end
  end
end

return { new = new_time_vortex, on_tick = on_tick, on_mode_switch = on_mode_switch }
