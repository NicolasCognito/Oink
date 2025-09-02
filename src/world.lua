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
local Spawner = require('systems.spawner')

local function create_world()
  local world = tiny.world()
  -- Order matters: spawner -> input -> agents -> move -> bounds -> zones -> collect
  world:add(Spawner({ interval = 2, margin = 10 }))
  world:add(Input())
  world:add(Agents())
  world:add(Move())
  world:add(Bounds(0))
  world:add(Zones())
  world:add(Collect())
  return world
end

return {
  create = create_world
}
