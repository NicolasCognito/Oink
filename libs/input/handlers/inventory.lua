local Inventory = require('inventory')
local spawn = require('spawn')

local function spawn_item(name, value, x, y)
  name = name or 'item'
  if name == 'coin' then
    local Coin = require('components.coin')
    return Coin.new(x, y, { value = value or 1 })
  elseif name == 'egg' then
    local Egg = require('components.egg')
    return Egg.new(x, y, { value = value or 1 })
  elseif name == 'ruby' then
    local Ruby = require('components.ruby')
    return Ruby.new(x, y, { value = value or 1 })
  else
    return {
      pos = { x = x or 0, y = y or 0 },
      drawable = true,
      radius = 3,
      color = {0.8,0.8,0.8,1},
      collectable = { name = name, value = value or 0 },
    }
  end
end

return function(opts)
  opts = opts or {}
  return {
    channel = 'actor',
    on = function(self, who, ctx, input, dt)
      if not who or not who.inventory then return end
      local inv = who.inventory
      -- select 1..9 on press
      for i = 1, math.min(inv.cap or 9, 9) do
        local key = tostring(i)
        if input.pressed(key) then
          if inv.active_index == i then inv.active_index = nil else inv.active_index = i end
          return
        end
      end
      -- drop one on Space
      if input.pressed('space') then
        local idx = inv.active_index
        if idx and inv.slots and inv.slots[idx] then
          local removed = Inventory.remove_one(inv, idx)
          if removed and who.pos then
            if removed.entity then
              local e = removed.entity
              e.pos = e.pos or { x = 0, y = 0 }
              e.pos.x, e.pos.y = who.pos.x, who.pos.y
              e.just_dropped_cd = 1.0
              spawn.request(e)
            else
              local item = spawn_item(removed.name, removed.value, who.pos.x, who.pos.y)
              item.just_dropped_cd = 1.0
              spawn.request(item)
            end
          end
        end
      end
    end
  }
end

