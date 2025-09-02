package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local ZoneCollect = require('systems.zone_collect')
local Vault = require('Zones.vault')

describe('vault zone', function()
  it('absorbs coins inside its rect into endless inventory', function()
    local w = tiny.world(Zones(), ZoneCollect())
    local vault = Vault.new(10, 10, 20, 20, { label = 'Vault' })
    local coin_in = { pos={x=15,y=15}, radius=1, coin=true, collectable={name='coin', value=2} }
    local coin_out = { pos={x=40,y=40}, radius=1, coin=true, collectable={name='coin', value=2} }
    w:add(vault); w:add(coin_in); w:add(coin_out)
    w:update(0)       -- apply
    w:update(0.016)   -- zones tick and remove coin_in
    w:update(0)       -- apply removals
    -- coin_in removed, coin_out remains
    local found_in, found_out = false, false
    for i=1,#w.entities do
      local e = w.entities[i]
      if e == coin_in then found_in = true end
      if e == coin_out then found_out = true end
    end
    assert.is_false(found_in)
    assert.is_true(found_out)
    assert.are.equal(1, vault.inventory.count)
    assert.are.equal(2, vault.inventory.value)
  end)
end)
