local function new_time_distortion(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'time_distortion',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 48 },
    label = opts.label or 'Time Distortion',
    drawable = true,
    factor = opts.factor or 0.5, -- speed multiplier when inside
    zone_state = { inside = {}, prev_speed = {} },
  }
end

local function contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function on_tick(zone, ctx)
  if zone.active == false then return end
  local agents = ctx.agents or {}
  local inside = zone.zone_state.inside or {}
  local prev_speed = zone.zone_state.prev_speed or {}
  zone.zone_state.inside = inside
  zone.zone_state.prev_speed = prev_speed

  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos and a.speed then
      local now = contains(zone.rect, a.pos.x, a.pos.y)
      local was = inside[a] or false
      if now and not was then
        -- Enter: cache original speed and apply factor
        if prev_speed[a] == nil then prev_speed[a] = a.speed end
        a.speed = (prev_speed[a] or a.speed) * (zone.factor or 0.5)
        inside[a] = true
      elseif (not now) and was then
        -- Exit: restore speed
        if prev_speed[a] ~= nil then
          a.speed = prev_speed[a]
          prev_speed[a] = nil
        end
        inside[a] = false
      end
    end
  end
end

return { new = new_time_distortion, on_tick = on_tick }

