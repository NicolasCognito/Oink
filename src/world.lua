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
local ZombieAI = require('systems.zombie_ai')
local Spawner = require('systems.spawner')

local function create_world()
  local world = tiny.world()
  -- Order matters: spawner -> input -> zombie_ai -> move -> bounds -> collect
  world:add(Spawner({ interval = 2, margin = 10 }))
  world:add(Input())
  world:add(ZombieAI({ aggro = 140, speed = 60 }))
  world:add(Move())
  world:add(Bounds(0))
  world:add(Collect())
  return world
end

return {
  create = create_world
}
