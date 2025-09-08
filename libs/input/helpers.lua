local M = {}

-- Builds a simple input snapshot with edge detection and axis
-- prev is a table stored by the caller between frames
function M.build_state(prev)
  prev = prev or {}
  local now = {}
  local held, pressed, released = {}, {}, {}

  local function isdown(k)
    return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(k) or false
  end

  -- Lazy key query so we don't need a global key list; handlers will query on demand
  local function key_held(key)
    local v = isdown(key)
    now[key] = v
    return v
  end

  local function key_pressed(key)
    local v = isdown(key)
    now[key] = v
    local was = prev[key] == true
    return v and not was
  end

  local function key_released(key)
    local v = isdown(key)
    now[key] = v
    local was = prev[key] == true
    return (not v) and was
  end

  -- Movement axis: WASD only (arrows reserved for UI)
  local function axis_move()
    local up    = isdown('w')
    local down  = isdown('s')
    local left  = isdown('a')
    local right = isdown('d')
    local ax = (right and 1 or 0) - (left and 1 or 0)
    local ay = (down and 1 or 0) - (up and 1 or 0)
    return ax, ay
  end

  local _repeat_acc = {}
  -- repeat key press helper with fixed cadence (seconds)
  local function repeat_pressed(key, rate, dt)
    rate = rate or 0.25
    _repeat_acc[key] = _repeat_acc[key] or { t = 0, fired = false }
    local state = _repeat_acc[key]
    -- fire immediately when key transitions to down
    if key_pressed(key) then
      state.t = 0
      state.fired = true
      return true
    end
    if not key_held(key) then
      state.t = 0
      state.fired = false
      return false
    end
    state.t = state.t + (dt or 0)
    if state.t >= rate then
      state.t = state.t - rate
      state.fired = true
      return true
    end
    return false
  end

  local function normalize(ax, ay)
    local mag = math.sqrt(ax*ax + ay*ay)
    if mag > 0 then return ax/mag, ay/mag end
    return 0, 0
  end

  local input = {
    held = key_held,
    pressed = key_pressed,
    released = key_released,
    repeatPressed = repeat_pressed,
    axis = {
      move = axis_move,
      normalize = normalize,
    },
    _now = now,
  }

  function input.commit()
    -- copy now into prev
    for k, v in pairs(now) do prev[k] = v end
    -- clear keys that were in prev but not touched now (assume up)
    for k, _ in pairs(prev) do
      if now[k] == nil then prev[k] = isdown(k) end
    end
    return prev
  end

  return input
end

return M

