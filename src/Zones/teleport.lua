local Coll = require('collision')

local function new_teleport(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'teleport',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Teleport [ON] (L=TP, R=Panel)',
    drawable = true,
    tx = opts.tx or 0,
    ty = opts.ty or 0,
    enabled = opts.enabled ~= false,
    zone_state = { inside_agents = {}, inside_items = {} },
    on_key = function(zone, player, key, ctx)
      key = string.lower(key or '')
      if key ~= 'p' or not player or not player.pos then return end
      local function is_panel(c) return c and c.id == 'panel' end
      if Coll.zone_any_contains_point(zone, player.pos.x, player.pos.y, { filter = is_panel }) then
        zone.enabled = not zone.enabled
        local status = zone.enabled and 'ON' or 'OFF'
        zone.label = string.format('Teleport [%s] (L=TP, R=Panel)', status)
      end
    end,
  }
  local bw, bh = (w or 48), (h or 32)
  z.colliders = {
    -- Left teleport area as a circle centered in the left half
    { kind = 'circle', id = 'left',  dx = bw * 0.25, dy = bh * 0.5, r = math.min(bw * 0.5, bh) * 0.5 },
    -- Right panel remains rectangular
    { kind = 'rect',   id = 'panel', dx = bw * 0.5,  dy = 0,         w = bw * 0.5,                 h = bh },
  }
  return z
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
      local function is_left(c) return c and c.id == 'left' end
      local now = Coll.zone_any_contains_point(zone, a.pos.x, a.pos.y, { filter = is_left })
      local was = ia[a] or false
      if now and not was then
        if zone.enabled ~= false then
          a.pos.x, a.pos.y = zone.tx or 0, zone.ty or 0
        end
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
      local function is_left(c) return c and c.id == 'left' end
      local now = Coll.zone_any_contains_point(zone, it.pos.x, it.pos.y, { filter = is_left })
      local was = ii[it] or false
      if now and not was then
        if zone.enabled ~= false then
          it.pos.x, it.pos.y = zone.tx or 0, zone.ty or 0
        end
        ii[it] = true
      elseif (not now) and was then
        ii[it] = false
      end
    end
  end
end

return { new = new_teleport, on_tick = on_tick }
