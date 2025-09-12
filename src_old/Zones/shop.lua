local Inventory = require('inventory')
local match = require('entity_match')
local spawn = require('spawn')
local Coin = require('components.coin')

local function new_shop(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'shop',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Shop',
    drawable = true,
    collector = true,
    inventory = Inventory.new(math.huge),
    zone_state = { },
    -- tuning
    process_interval = opts.process_interval or 0.2,
    give_radius = opts.give_radius or 12,
  }

  -- Reserve slots for clarity and deterministic consumption order
  Inventory.reserve_slot(z.inventory, 1, 'ruby')
  Inventory.reserve_slot(z.inventory, 2, 'egg')

  -- Absorb only rubies and eggs
  z.collect_query = match.build_query({
    whitelist = function(_, it)
      local n = it and it.collectable and it.collectable.name
      return n == 'ruby' or n == 'egg'
    end
  })
  z.accept_collectable = function(self, item)
    local n = item and item.collectable and item.collectable.name
    return n == 'ruby' or n == 'egg'
  end

  return z
end

local function spawn_coin_near(zone, value)
  local cx = zone.rect.x + zone.rect.w * 0.5
  local cy = zone.rect.y + zone.rect.h * 0.5
  local r = zone.give_radius or 12
  local ang = math.random() * math.pi * 2
  local d = math.random() * r
  local x = cx + math.cos(ang) * d
  local y = cy + math.sin(ang) * d
  spawn.request(Coin.new(x, y, { value = value or 1 }))
end

local function on_tick(zone, ctx, dt)
  if zone.active == false then return end
  dt = dt or 0
  zone._proc_t = (zone._proc_t or 0) + dt
  local interval = zone.process_interval or 0.2
  while zone._proc_t >= interval do
    zone._proc_t = zone._proc_t - interval
    local inv = zone.inventory
    if not inv or not inv.slots then return end
    -- Convert all available rubies and eggs into coins at 1:1 count
    -- Consume from reserved slots 1 (ruby) and 2 (egg)
    for _, slot_index in ipairs({1, 2}) do
      local s = inv.slots[slot_index]
      while s and (s.count or 0) > 0 do
        local removed = Inventory.remove_one(inv, slot_index)
        if removed then
          -- Spawn one coin per item consumed. Use item's value as coin value.
          spawn_coin_near(zone, removed.value or 1)
        else
          break
        end
      end
    end
  end
end

return { new = new_shop, on_tick = on_tick }

