local function rotate_next(modes)
  if not modes or #modes <= 1 then return nil, nil end
  local prev = modes[1]
  table.remove(modes, 1)
  table.insert(modes, prev)
  local nextm = modes[1]
  return prev, nextm
end

local function rotate_prev(modes)
  if not modes or #modes <= 1 then return nil, nil end
  local prev = modes[1]
  local last = table.remove(modes)
  table.insert(modes, 1, last)
  local nextm = modes[1]
  return prev, nextm
end

return function(opts)
  opts = opts or {}
  local rate = opts.repeat_rate or 0.25
  return {
    channel = 'zone',
    on = function(self, zone, ctx, input, dt)
      if not zone or not zone.modes or #zone.modes == 0 then return end
      local prev, nextm
      if input.repeatPressed('e', rate, dt) then
        prev, nextm = rotate_next(zone.modes)
      elseif input.repeatPressed('q', rate, dt) then
        prev, nextm = rotate_prev(zone.modes)
      end
      if nextm and zone.on_mode_change then
        zone.on_mode_change(zone, prev, nextm, ctx)
      end
    end
  }
end
