package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Move = require('systems.move')
local Input = require('systems.input')
local Bounds = require('systems.bounds')
local Collect = require('systems.collect')
local Agents = require('systems.agents')
local Zones = require('systems.zones')
local ZoneCollect = require('systems.zone_collect')
local Spawner = require('systems.spawner')

local function create_world()
  local world = tiny.world()
  -- Order matters (zones and zone_collect before agents):
  -- spawner -> input -> zones -> zone_collect -> agents -> move -> bounds -> collect
  world:add(Spawner({ interval = 0.5, margin = 10 }))
  world:add(Input())
  world:add(Zones())
  world:add(ZoneCollect())
  world:add(Agents())
  world:add(Move())
  world:add(Bounds(0))
  world:add(Collect())
  return world
end

return {
  create = create_world
}
