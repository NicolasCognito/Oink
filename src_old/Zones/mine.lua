local spawn = require('spawn')
local Ruby = require('components.ruby')
local Coll = require('collision')

local function new_mine(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'mine',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Mine',
    drawable = true,
    production_interval = opts.production_interval or 1.0,
    production_radius = opts.production_radius or 16,
    zone_state = { timers = {} },
  }
end

local function on_tick(zone, ctx, dt)
  if zone.active == false then return end
  dt = dt or 0
  local agents = ctx.agents or {}
  local timers = zone.zone_state.timers or {}
  zone.zone_state.timers = timers

  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos and a._mining then
      if Coll.rect_contains_point(zone.rect, a.pos.x, a.pos.y) then
        local t = timers[a] or 0
        t = t + dt
        local interval = zone.production_interval or 1.0
        while t >= interval do
          t = t - interval
          local r = zone.production_radius or 16
          local angle = math.random() * math.pi * 2
          local dist = math.random() * r
          local rx = a.pos.x + math.cos(angle) * dist
          local ry = a.pos.y + math.sin(angle) * dist
          spawn.request(Ruby.new(rx, ry, { value = 1 }))
        end
        timers[a] = t
      else
        timers[a] = 0
      end
    end
  end
end

return { new = new_mine, on_tick = on_tick }

