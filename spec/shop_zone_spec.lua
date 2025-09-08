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
local Shop = require('Zones.shop')
local Ruby = require('components.ruby')
local Egg = require('components.egg')

local function count_coins(world)
  local n = 0
  for _, e in ipairs(world.entities) do
    if e and e.collectable and e.collectable.name == 'coin' then n = n + 1 end
  end
  return n
end

describe('shop zone', function()
  it('converts dropped rubies and eggs into coins', function()
    local w = tiny.world(Context(), Zones(), ZoneCollect(), Spawner())
    local shop = Shop.new(0, 0, 40, 40, { label = 'Shop', process_interval = 0.05 })
    shop.on_tick = Shop.on_tick
    w:add(shop)

    -- Drop a ruby and an egg inside the shop area
    local r = Ruby.new(10, 10, { value = 1 })
    local e = Egg.new(12, 12, { value = 1, ttl = 60 })
    w:add(r)
    w:add(e)

    -- First update: zone_collect absorbs items into shop inventory
    w:update(0.016)
    -- Second update: shop processes inventory and requests coin spawns
    w:update(0.1)
    -- Drain spawns into the world
    w:update(0)

    assert.are.equal(2, count_coins(w))
  end)
end)

