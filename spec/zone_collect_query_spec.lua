package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local ZoneCollect = require('systems.zone_collect')
local Inventory = require('inventory')

describe('zone_collect collect_query override', function()
  it('uses zone.collect_query to limit candidates', function()
    local w = tiny.world(Zones(), ZoneCollect())
    local zone = { zone=true, rect={x=0,y=0,w=20,h=20}, collector=true, inventory=Inventory.new(100) }
    -- collect_query returns empty set; nothing should be absorbed
    function zone.collect_query(self, ctx) return {} end
    local coin = { pos={x=10,y=10}, collectable={name='coin', value=1} }
    w:add(zone); w:add(coin)
    w:update(0); w:update(0.016); w:update(0)
    -- coin must remain and inventory should be unchanged
    local found = false
    for i=1,#w.entities do if w.entities[i] == coin then found = true end end
    assert.is_true(found)
    assert.are.equal(0, zone.inventory.count)
  end)
end)

