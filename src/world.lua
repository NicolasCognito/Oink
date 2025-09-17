package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local bt = require('tiny-bt')

local CoinSpawn = require('systems.coin_spawn')
local MoveSystem = require('systems.move')
local RendererSystem = require('systems.renderer')

local function create_world()
  local world = tiny.world()
  -- Minimal system set: BT -> spawner -> move -> renderer
  world:add(bt.system{})
  world:add(CoinSpawn())
  world:add(MoveSystem())
  world:add(RendererSystem())
  return world
end

return {
  create = create_world
}
