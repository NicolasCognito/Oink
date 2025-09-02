package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Inventory = require('inventory')

local function rect_contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

return function()
  local sys = tiny.processingSystem()
  -- Zones with rectangular collectors and inventories
  sys.filter = tiny.requireAll('zone', 'collector', 'rect', 'inventory')

  function sys:preProcess(dt)
    -- Capture collectables snapshot
    local items = {}
    local idx = 1
    for i = 1, #self.world.entities do
      local e = self.world.entities[i]
      if e and e.collectable and e.pos then
        items[idx] = e
        idx = idx + 1
      end
    end
    self._collectables = items
  end

  function sys:process(zone, dt)
    if zone.active == false then return end
    local rect = zone.rect
    if not rect then return end
    local accept = zone.accept_collectable
    local ctx = { world = self.world, collectables = self._collectables }
    local used_query = (zone.collect_query ~= nil)
    local items = (used_query and zone.collect_query(zone, ctx)) or ctx.collectables
    for i = 1, #items do
      local it = items[i]
      if it and it.pos and rect_contains(rect, it.pos.x, it.pos.y) then
        local name = (it.collectable and it.collectable.name) or nil
        local val = (it.collectable and it.collectable.value) or 0
        -- Zone defines what to absorb.
        -- If a custom query was used, assume items are pre-filtered.
        local ok_type = used_query and true or (accept and accept(zone, it))
        if ok_type then
          if Inventory.add(zone.inventory, name or 'item', val) then
            self.world:remove(it)
          end
        end
      end
    end
  end

  return sys
end
