local Coll = require('collision')
local avatar = require('avatar')

-- forward declare
local on_input

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
  }
  -- attach input handler for panel toggle
  z.on_input = on_input
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
  -- Presence mode: teleport entities whenever they are inside the trigger region
  -- NOTE: This runs without saferails (no cooldowns, no nudges). If destination
  --       lands inside a teleporter (this or another), entities may teleport
  --       repeatedly or ping-pong. Consider adding a cooldown/ignore window later.

  -- Agents
  local agents = ctx.agents or {}
  for i = 1, #agents do
    local a = agents[i]
    if a and a.pos then
      local function is_left(c) return c and c.id == 'left' end
      if zone.enabled ~= false and Coll.zone_any_contains_point(zone, a.pos.x, a.pos.y, { filter = is_left }) then
        a.pos.x, a.pos.y = zone.tx or 0, zone.ty or 0
      end
    end
  end

  -- Collectables
  local items = ctx.collectables or {}
  for i = 1, #items do
    local it = items[i]
    if it and it.pos then
      local function is_left(c) return c and c.id == 'left' end
      if zone.enabled ~= false and Coll.zone_any_contains_point(zone, it.pos.x, it.pos.y, { filter = is_left }) then
        it.pos.x, it.pos.y = zone.tx or 0, zone.ty or 0
      end
    end
  end
end

-- Direct input: toggle enabled when player presses P while in the panel region
function on_input(zone, input, ctx)
  if not input or not input.pressed then return end
  if not input.pressed('p') then return end
  local p = (ctx and ctx.player) or (ctx and ctx.active_avatar)
  if (not p) and ctx and ctx.world and avatar and avatar.get then p = avatar.get(ctx.world) end
  if not p or not p.pos then return end
  local function is_panel(c) return c and c.id == 'panel' end
  if Coll.zone_any_contains_point(zone, p.pos.x, p.pos.y, { filter = is_panel }) then
    zone.enabled = not zone.enabled
    local status = zone.enabled and 'ON' or 'OFF'
    zone.label = string.format('Teleport [%s] (L=TP, R=Panel)', status)
  end
end

return { new = new_teleport, on_tick = on_tick, on_input = on_input }
