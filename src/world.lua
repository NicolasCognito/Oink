package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Move = require('systems.move')
local Input = require('systems.input')
local Context = require('systems.context_provider')
local Bounds = require('systems.bounds')
local Collect = require('systems.collect')
local Agents = require('systems.agents')
local Zones = require('systems.zones')
local ZoneCollect = require('systems.zone_collect')
local Collectables = require('systems.collectables')
local Expiry = require('systems.expiry')
local Destroyer = require('systems.destroyer')
local CoinSpawner = require('systems.coin_spawner')
local QueueSpawner = require('systems.spawner')
local InputInventory = require('systems.input_inventory')

local function create_world()
  local world = tiny.world()
  -- Order matters:
  -- input -> context -> zones -> zone_collect -> agents -> move -> bounds -> collectables -> collect -> destroyer -> spawner
  world:add(CoinSpawner({ interval = 0.5, margin = 10 }))
  world:add(Input())
  world:add(InputInventory())
  world:add(Context())
  world:add(Zones())
  world:add(ZoneCollect())
  world:add(Agents())
  world:add(Move())
  world:add(Bounds(0))
  world:add(Collectables())
  world:add(Expiry())
  world:add(Collect())
  world:add(Destroyer())
  world:add(QueueSpawner())
  return world
end

return {
  create = create_world
}
