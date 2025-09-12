package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local collision = require('collision')
local Inventory = require('inventory')

return function()
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('collectable', 'pos')
  sys.collectors = nil

  local function refresh_collectors(self)
    self.collectors = {}
    local idx = 1
    for i = 1, #self.world.entities do
      local ent = self.world.entities[i]
      if ent and ent.collector and ent.pos and ent.inventory then
        self.collectors[idx] = ent
        idx = idx + 1
      end
    end
  end

  function sys:preProcess(dt)
    refresh_collectors(self)
    -- Snapshot all collectables for per-collector queries
    local items = {}
    local ii = 1
    for i = 1, #self.world.entities do
      local e = self.world.entities[i]
      if e and e.collectable and e.pos and (not e.marked_for_destruction) then items[ii] = e; ii = ii + 1 end
    end
    self._collectables = items
    -- Build membership sets for collectors with custom queries
    self._collector_sets = {}
    local ctx = { world = self.world, collectables = self._collectables }
    for i = 1, #self.collectors do
      local c = self.collectors[i]
      if c.collect_query then
        local list = c.collect_query(c, ctx) or {}
        local set = {}
        for j = 1, #list do set[list[j]] = true end
        self._collector_sets[c] = set
      end
    end
  end

  function sys:process(coin, dt)
    if not self.collectors or #self.collectors == 0 then return end
    if coin.marked_for_destruction then return end
    if coin.just_dropped_cd and (coin.just_dropped_cd or 0) > 0 then
      coin.just_dropped_cd = math.max(0, (coin.just_dropped_cd or 0) - (dt or 0))
      return
    end
    local cr = coin.radius or 0
    for i = 1, #self.collectors do
      local c = self.collectors[i]
      -- Fundamental safety: a collector must never collect itself
      if c == coin then goto next_collector end
      local rr = c.radius or 0
      -- Check collector's desired items: either membership via collect_query set, or accept_collectable predicate
      local allowed = false
      local set = self._collector_sets and self._collector_sets[c]
      if set then
        allowed = set[coin] == true
      elseif c.accept_collectable then
        allowed = c.accept_collectable(c, coin)
      else
        allowed = false
      end
      if allowed and collision.circles_overlap(c.pos, rr, coin.pos, cr) then
        local inv = c.inventory
        local data = coin.collectable or { name = 'item', value = 0 }
        if inv then
          if data.persistent then
            if Inventory.add_entity(inv, coin) then self.world:remove(coin) end
          else
            if Inventory.add(inv, data.name, data.value) then self.world:remove(coin) end
          end
        end
        break
      end
      ::next_collector::
    end
  end

  return sys
end
