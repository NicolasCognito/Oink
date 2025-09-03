package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
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
    -- Generic collectable fallback
    return {
      pos = { x = x or 0, y = y or 0 },
      drawable = true,
      radius = 3,
      color = {0.8,0.8,0.8,1},
      collectable = { name = name, value = value or 0 },
    }
  end
end

return function()
  local sys = tiny.system()
  sys._key_cd = 0
  sys._prev = {}

  local function keydown(key)
    return love.keyboard.isDown(key)
  end

  local function pressed(self, key)
    local now = keydown(key)
    local was = self._prev[key] == true
    self._prev[key] = now
    return now and not was
  end

  function sys:update(dt)
    self._key_cd = math.max(0, (self._key_cd or 0) - (dt or 0))
    -- Find player with inventory
    local player
    for i = 1, #self.world.entities do
      local e = self.world.entities[i]
      if e and e.player and e.inventory then player = e; break end
    end
    if not player then return end
    local inv = player.inventory

    -- Handle slot selection 1..9
    for i = 1, math.min(inv.cap or 9, 9) do
      local key = tostring(i)
      if pressed(self, key) then
        if inv.active_index == i then inv.active_index = nil else inv.active_index = i end
        return -- one action per frame
      end
    end

    -- Drop from active slot on Space
    if pressed(self, 'space') then
      local idx = inv.active_index
      if idx and inv.slots and inv.slots[idx] then
        local removed = Inventory.remove_one(inv, idx)
        if removed and player.pos then
          local item = spawn_item(removed.name, removed.value, player.pos.x, player.pos.y)
          spawn.request(item)
        end
      end
    end
  end

  return sys
end

