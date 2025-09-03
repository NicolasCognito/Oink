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
local Mine = require('Zones.mine')
local Miner = require('components.miner')

local function count_rubies(world)
  local n = 0
  for _, e in ipairs(world.entities) do
    if e and e.collectable and e.collectable.name == 'ruby' then n = n + 1 end
  end
  return n
end

describe('mine zone and miner', function()
  it('produces rubies around a working miner', function()
    local w = tiny.world(Zones(), Agents(), Move(), Spawner())
    local z = Mine.new(0,0,40,40, { production_interval = 0.2, production_radius = 8 })
    z.on_tick = Mine.on_tick
    local m = Miner.new({ x = 10, y = 10, speed = 0 })
    w:add(z); w:add(m)
    -- run time to allow miner to enter and work
    for _=1,5 do w:update(0.1) end
    -- drain spawns
    w:update(0)
    assert.is_true(count_rubies(w) > 0)
  end)
end)

