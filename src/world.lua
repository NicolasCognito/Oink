package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local bt = require('tiny-bt-tasks')

local CoinSpawn = require('systems.coin_spawn')
local MoveSystem = require('systems.move')
local TaskMoveTo = require('systems.tasks.move_to')
local TaskFind = require('systems.tasks.find')
local TaskPickup = require('systems.tasks.pickup')
local TaskHalt = require('systems.tasks.halt')
local TaskChase = require('systems.tasks.chase')
local TaskFlee = require('systems.tasks.flee')
local TaskCheck = require('systems.tasks.check')
local RendererSystem = require('systems.renderer')

local function create_world()
  local world = tiny.world()
  -- Minimal system set: BT -> spawner -> task runners -> move -> renderer
  world:add(bt.system{})
  world:add(CoinSpawn())
  world:add(TaskFind())
  world:add(TaskChase())
  world:add(TaskMoveTo())
  world:add(TaskCheck())
  world:add(TaskFlee())
  world:add(TaskPickup())
  world:add(TaskHalt())
  world:add(MoveSystem())
  world:add(RendererSystem())
  return world
end

return {
  create = create_world
}
