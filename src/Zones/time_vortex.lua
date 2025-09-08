local H_zone_mode = require('input.handlers.zone_mode')
local Coll = require('collision')

-- Standardized mode change hook (define before constructor so it can be attached)
local function on_mode_change(zone, prev_mode, next_mode, ctx)
  if next_mode and next_mode.scale then
    zone.scale = next_mode.scale
  end
  -- Label remains the base label; draw layer appends the current mode name

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

local function new_time_vortex(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'time_vortex',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 48 },
    label = opts.label or 'Time',
    drawable = true,
    input_priority = opts.input_priority or 1,
    scale = opts.scale or 2.0, -- time multiplier applied to affected entities
    affect_items = opts.affect_items or false,
    affect_zones = (opts.affect_zones ~= false),
    affected = {},
    -- optional modes: array; first element is active
    modes = opts.modes,
  }
  if z.modes and z.modes[1] then
    local active = z.modes[1]
    z.scale = active.scale or z.scale
  end
  if z.modes and #z.modes > 0 then
    z.input_handlers = z.input_handlers or {}
    table.insert(z.input_handlers, H_zone_mode({ repeat_rate = 0.25 }))
    -- Provide standardized mode-change hook for handlers
    z.on_mode_change = on_mode_change
  end
  return z
end

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

return { new = new_time_vortex, on_tick = on_tick, on_mode_change = on_mode_change }
