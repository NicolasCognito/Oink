local function new_bear_trap(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'bear_trap',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 16, h = h or 16 },
    zone_state = { inside = {} },
    label = opts.label or 'Bear Trap',
    drawable = true,
  }
end

local function on_enter(zone, agent, world)
  if not zone.active then return end
  -- Kill first agent entering and deactivate
  world:remove(agent)
  zone.active = false
end

local function contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function on_tick(zone, ctx)
  if not zone.active then return end
  local agents = ctx.agents or {}
  local rect = zone.rect or {x=0,y=0,w=0,h=0}
  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos and contains(rect, a.pos.x, a.pos.y) then
      ctx.world:remove(a)
      zone.active = false
      break
    end
  end
end

return { new = new_bear_trap, on_enter = on_enter, on_tick = on_tick }
