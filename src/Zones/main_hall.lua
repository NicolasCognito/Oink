local spawn = require('spawn')
local Inventory = require('inventory')
local TaxCollector = require('components.tax_collector')

local H_zone_mode = require('input.handlers.zone_mode')

local function new_main_hall(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'main_hall',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 60, h = h or 40 },
    label = opts.label or 'Main Hall',
    drawable = true,
    modes = { { id='spawn_collector', name='Spawn' }, { id='buff_collectors', name='Buff' } },
    _sink = { items = {}, items_value = {}, count = 0, value = 0 },
  }
  -- attach mode handler for Q/E rotation
  z.input_handlers = z.input_handlers or {}
  table.insert(z.input_handlers, H_zone_mode({ repeat_rate = 0.25 }))
  return z
end

local function find_vault(ctx)
  local zones = ctx.zones or {}
  for i = 1, #zones do
    local z = zones[i]
    if z and z.collector and z.inventory and z.rect then
      return z
    end
  end
end

local function spawn_collector(zone, ctx)
  local vault = find_vault(ctx)
  if not (vault and vault.inventory) then return end
  -- spend 10 coins
  Inventory.transfer(vault.inventory, zone._sink, { names = {'coin'}, max_count = 10 })
  if (zone._sink.count or 0) >= 10 then
    zone._sink.items = {}; zone._sink.items_value = {}; zone._sink.count = 0; zone._sink.value = 0
    local cx = zone.rect.x + zone.rect.w/2
    local cy = zone.rect.y + zone.rect.h/2
    spawn.request(TaxCollector.new({ x = cx + (math.random()*2-1)*8, y = cy + (math.random()*2-1)*8 }))
  end
end

local function buff_collectors(zone, ctx)
  local vault = find_vault(ctx)
  if not (vault and vault.inventory) then return end
  Inventory.transfer(vault.inventory, zone._sink, { names = {'coin'}, max_count = 50 })
  if (zone._sink.count or 0) >= 50 then
    zone._sink.items = {}; zone._sink.items_value = {}; zone._sink.count = 0; zone._sink.value = 0
    local agents = ctx.agents or {}
    local TaxFSM = require('FSMs.tax_collector')
    for i = 1, #agents do
      local a = agents[i]
      if a and a.brain and a.brain.fsm_def == TaxFSM and a.speed then
        a.speed = a.speed * 1.3
      end
    end
  end
end

local actions = {
  spawn_collector = spawn_collector,
  buff_collectors = buff_collectors,
}

local function on_tick(zone, ctx)
  if zone.active == false then return end
  local active = zone.modes and zone.modes[1]
  local key = active and (active.id or active)
  local fn = key and actions[key] or nil
  if fn then fn(zone, ctx) end
end

local function _on_mode_change(zone, prev, nextm)
  local name = (nextm and (nextm.name or nextm.id)) or '?'
  zone.label = 'Main Hall: ' .. tostring(name)
end

return { new = new_main_hall, on_tick = on_tick, _on_mode_change = _on_mode_change }
