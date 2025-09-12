local Inventory = require('inventory')
local spawn = require('spawn')
local Ruby = require('components.ruby')

local function new_token_mine(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'token_mine',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Token Mine',
    drawable = true,
    collector = true,
    inventory = Inventory.new(math.huge),
    zone_state = { timers = {} },
    -- Conversion/give tuning
    work_to_ruby = opts.work_to_ruby or 5, -- N work -> 1 ruby
    process_interval = opts.process_interval or 0.5,
    give_interval = opts.give_interval or 1.2,
    give_radius = opts.give_radius or 12,
  }
  -- Reserve slots for clarity and stable indices
  Inventory.reserve_slot(z.inventory, 1, 'work')
  Inventory.reserve_slot(z.inventory, 2, 'ruby')

  -- Only absorb work tokens: use policy-built collect_query (keeps accept_collectable for back-compat)
  local match = require('entity_match')
  z.collect_query = match.build_query({
    whitelist = function(_, it)
      return it and it.collectable and it.collectable.name == 'work'
    end
  })
  z.accept_collectable = function(self, item)
    return item and item.collectable and item.collectable.name == 'work'
  end

  return z
end

local function on_tick(zone, ctx, dt)
  if zone.active == false then return end
  dt = dt or 0
  zone._proc_t = (zone._proc_t or 0) + dt
  zone._give_t = (zone._give_t or 0) + dt

  -- Convert work -> ruby in batches each process interval
  local proc_int = zone.process_interval or 0.5
  while zone._proc_t >= proc_int do
    zone._proc_t = zone._proc_t - proc_int
    local inv = zone.inventory
    local ratio = math.max(1, zone.work_to_ruby or 5)
    local work_count = (inv.items and inv.items['work']) or 0
    local can_make = math.floor(work_count / ratio)
    if can_make > 0 then
      -- Spend work tokens from slot 1 and credit ruby into slot 2
      for n = 1, can_make do
        for i = 1, ratio do
          Inventory.remove_one(inv, 1)
        end
        Inventory.add(inv, 'ruby', 1)
      end
    end
  end

  -- Occasionally give a ruby to the world (drop from slot 2)
  local give_int = zone.give_interval or 1.2
  while zone._give_t >= give_int do
    zone._give_t = zone._give_t - give_int
    local inv = zone.inventory
    local ruby_count = (inv.items and inv.items['ruby']) or 0
    if ruby_count > 0 then
      -- Remove one ruby from reserved slot 2 and spawn a ruby entity near center
      local removed = Inventory.remove_one(inv, 2)
      if removed then
        local cx = zone.rect.x + zone.rect.w * 0.5
        local cy = zone.rect.y + zone.rect.h * 0.5
        local r = zone.give_radius or 12
        local ang = math.random() * math.pi * 2
        local d = math.random() * r
        local x = cx + math.cos(ang) * d
        local y = cy + math.sin(ang) * d
        spawn.request(Ruby.new(x, y, { value = removed.value or 1 }))
      end
    end
  end
end

return { new = new_token_mine, on_tick = on_tick }
