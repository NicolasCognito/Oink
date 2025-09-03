local Coll = require('collision')

local function new_teleport(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'teleport',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Teleport',
    drawable = true,
    tx = opts.tx or 0,
    ty = opts.ty or 0,
    zone_state = { inside_agents = {}, inside_items = {} },
  }
end

local function on_tick(zone, ctx)
  if zone.active == false then return end
  local rect = zone.rect
  local ia = zone.zone_state.inside_agents or {}
  local ii = zone.zone_state.inside_items or {}
  zone.zone_state.inside_agents = ia
  zone.zone_state.inside_items = ii

  -- Agents
  local agents = ctx.agents or {}
  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos then
      local now = Coll.rect_contains_point(rect, a.pos.x, a.pos.y)
      local was = ia[a] or false
      if now and not was then
        a.pos.x, a.pos.y = zone.tx or 0, zone.ty or 0
        ia[a] = true
      elseif (not now) and was then
        ia[a] = false
      end
    end
  end

  -- Collectables
  local items = ctx.collectables or {}
  for i = 1, #items do
    local it = items[i]
    if it and it.pos then
      local now = Coll.rect_contains_point(rect, it.pos.x, it.pos.y)
      local was = ii[it] or false
      if now and not was then
        it.pos.x, it.pos.y = zone.tx or 0, zone.ty or 0
        ii[it] = true
      elseif (not now) and was then
        ii[it] = false
      end
    end
  end
end

return { new = new_teleport, on_tick = on_tick }

