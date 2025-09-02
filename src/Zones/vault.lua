local Inventory = require('inventory')

local function new_vault(x, y, w, h, opts)
  opts = opts or {}
  return {
    zone = true,
    type = 'vault',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 32, h = h or 32 },
    zone_state = { },
    label = opts.label or 'Vault',
    drawable = true,
    collector = true,
    inventory = Inventory.new(math.huge),
    -- Absorb policy: coins only by default; override via accept_collectable or collect_query
    accept_collectable = function(self, item)
      return item and item.collectable and item.collectable.name == 'coin'
    end,
  }
end

local function contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function on_tick(zone, ctx)
  if zone.active == false then return end
  local items = ctx.collectables or {}
  for i = 1, #items do
    local it = items[i]
    if it and it.pos and it.collectable and it.collectable.name == 'coin' then
      if contains(zone.rect, it.pos.x, it.pos.y) then
        local ok = Inventory.add(zone.inventory, it.collectable.name, it.collectable.value or 0)
        if ok then
          ctx.world:remove(it)
        end
      end
    end
  end
end

return { new = new_vault, on_tick = on_tick }
