package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Inventory = require('inventory')
local ctx = require('ctx')

local function rect_contains(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

return function()
  local sys = tiny.processingSystem()
  -- Zones with rectangular collectors and inventories
  sys.filter = tiny.requireAll('zone', 'collector', 'rect', 'inventory')

  function sys:process(zone, dt)
    if zone.active == false then return end
    local rect = zone.rect
    if not rect then return end
    local accept = zone.accept_collectable
    local snapshot = ctx.get(self.world, dt)
    local used_query = (zone.collect_query ~= nil)
    local items = (used_query and zone.collect_query(zone, snapshot)) or (snapshot.collectables or {})
    for i = 1, #items do
      local it = items[i]
      if it and it.pos then
        -- cooldown countdown
        if it.just_dropped_cd and (it.just_dropped_cd or 0) > 0 then
          it.just_dropped_cd = math.max(0, (it.just_dropped_cd or 0) - (dt or 0))
        end
        if (it.just_dropped_cd and it.just_dropped_cd > 0) then goto continue end
        if not rect_contains(rect, it.pos.x, it.pos.y) then goto continue end
        local name = (it.collectable and it.collectable.name) or nil
        local val = (it.collectable and it.collectable.value) or 0
        -- Zone defines what to absorb.
        -- If a custom query was used, assume items are pre-filtered.
        local ok_type = used_query and true or (accept and accept(zone, it))
        if ok_type then
          if Inventory.add(zone.inventory, name or 'item', val) then
            it.marked_for_destruction = true
            snapshot.world:remove(it)
          end
        end
      end
      ::continue::
    end
  end

  return sys
end
