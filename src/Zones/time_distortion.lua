local function new_time_distortion(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'time_distortion',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 48 },
    label = opts.label or 'Time Distortion',
    drawable = true,
    factor = opts.factor or 0.5, -- velocity multiplier when inside
  }
end

local function contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function on_tick(zone, ctx)
  if zone.active == false then return end
  local agents = ctx.agents or {}
  local factor = zone.factor or 0.5
  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos and a.vel then
      if contains(zone.rect, a.pos.x, a.pos.y) then
        a.vel.x = (a.vel.x or 0) * factor
        a.vel.y = (a.vel.y or 0) * factor
      end
    end
  end
end

return { new = new_time_distortion, on_tick = on_tick }
