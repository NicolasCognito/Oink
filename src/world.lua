package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local bt = require('tiny-bt-tasks')
local fsm = require('tiny-fsm')

local CoinSpawn = require('systems.coin_spawn')
local CollectorSpeed = require('systems.collector_speed')
local CollectorTargeting = require('systems.collector_targeting')
local InputSystem = require('systems.input')
local RendererSystem = require('systems.renderer')
local MoveTaskSystem = require('systems.bt_task_move')
local PickupTaskSystem = require('systems.bt_task_pickup')
local DepositTaskSystem = require('systems.bt_task_deposit')

local function create_world()
  local world = tiny.world()
  -- Order: FSM effects -> speed -> spawner -> targeting -> BT -> tasks
  world:add(fsm.system{})
  world:add(InputSystem())
  world:add(CollectorSpeed())
  world:add(CoinSpawn())
  world:add(CollectorTargeting())
  world:add(bt.system{})
  world:add(MoveTaskSystem())
  world:add(PickupTaskSystem())
  world:add(DepositTaskSystem())
  world:add(RendererSystem())
  return world
end

return {
  create = create_world
}
