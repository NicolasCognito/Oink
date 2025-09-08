package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local ZoneCollect = require('systems.zone_collect')
local Context = require('systems.context_provider')
local Spawner = require('systems.spawner')
local Collect = require('systems.collect')
local Vault = require('Zones.vault')
local Inventory = require('inventory')
local spawn = require('spawn')

describe('dropping on vault', function()
  it('coin dropped on vault goes into vault, not back to player', function()
    local w = tiny.world(Context(), Zones(), ZoneCollect(), Collect(), Spawner())
    local vault = Vault.new(0, 0, 40, 40, { label = 'Vault' })
    w:add(vault)

    -- Minimal player with inventory and collector behavior
    local player = {
      player = true,
      pos = { x = 10, y = 10 },
      radius = 6,
      collector = true,
      inventory = Inventory.new(9),
      accept_collectable = function(self, item) return item and item.collectable end,
    }
    -- Seed player with one coin
    Inventory.add(player.inventory, 'coin', 1)
    assert.are.equal(1, player.inventory.count)
    w:add(player)

    -- Simulate drop: remove one from active slot (assume slot 1) and spawn at player pos
    player.inventory.active_index = 1
    local removed = Inventory.remove_one(player.inventory, 1)
    assert.is_not_nil(removed)
    spawn.request({
      pos = { x = player.pos.x, y = player.pos.y },
      drawable = true,
      radius = 3,
      color = {1,1,0,1},
      collectable = { name = removed.name, value = removed.value },
    })

    -- Drain spawns and process systems
    w:update(0)      -- spawner adds coin
    w:update(0.016)  -- zones + zone_collect absorb
    w:update(0)      -- apply removals

    -- Player inventory should remain 0; vault should have 1
    assert.are.equal(0, player.inventory.count)
    assert.are.equal(1, vault.inventory.count)
  end)
end)
