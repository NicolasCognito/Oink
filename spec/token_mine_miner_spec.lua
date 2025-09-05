package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Agents = require('systems.agents')
local Move = require('systems.move')
local Spawner = require('systems.spawner')
local ZoneCollect = require('systems.zone_collect')
local Expiry = require('systems.expiry')
local TokenMine = require('Zones.token_mine')
local TokenMiner = require('components.token_miner')

local function count_rubies(world)
  local n = 0
  for _, e in ipairs(world.entities) do
    if e and e.collectable and e.collectable.name == 'ruby' then n = n + 1 end
  end
  return n
end

describe('token mine and token miner', function()
  it('converts work tokens and occasionally gives rubies', function()
    local w = tiny.world(Zones(), ZoneCollect(), Agents(), Move(), Expiry(), Spawner())
    local z = TokenMine.new(0,0,40,40, { work_to_ruby = 2, process_interval = 0.1, give_interval = 0.2 })
    z.on_tick = TokenMine.on_tick
    local m = TokenMiner.new({ x = 10, y = 10, speed = 0, work_drop_interval = 0.2, work_token_ttl = 2.0 })
    w:add(z); w:add(m)
    -- Simulate enough time for drops, conversion, and giving
    for _=1,20 do w:update(0.1) end
    -- drain spawns
    w:update(0)
    assert.is_true(count_rubies(w) > 0)
  end)
end)

