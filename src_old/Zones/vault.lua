local Inventory = require('inventory')
local match = require('entity_match')

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
    -- Absorb policy: coins only by default; prefer policy-built collect_query
    collect_query = match.build_query({
      whitelist = function(_, it)
        return it and it.collectable and it.collectable.name == 'coin'
      end
    }),
    -- Back-compat path for systems that consult accept_collectable
    accept_collectable = function(self, item)
      return item and item.collectable and item.collectable.name == 'coin'
    end,
  }
end

local function contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

-- ZoneCollect system handles collection using collect_query; keep helper for rectangle checks
return { new = new_vault, on_tick = nil }
