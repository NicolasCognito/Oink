package.path = table.concat({
  package.path,
  'src/?.lua','src/?/init.lua',
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local World = require('world')
local comps = require('sim.components')
local bt_defs = require('sim.bt_defs')
local fsm_defs = require('sim.fsm_defs')

local M = {}

function M.load()
  M.world = World.create()
  math.randomseed(42)

  -- Globals & spawner
  M.world:add(comps.new_globals())
  local spawner = comps.new_spawner()
  -- prime for an immediate spawn on first update
  spawner.acc = spawner.interval
  M.world:add(spawner)
  M.world:add(comps.new_input())

  -- Vault with FSM (default mode 'spawn')
  local vault = comps.new_vault({ x = 100, y = 100 })
  fsm_defs.attach_vault_fsm(vault)
  M.world:add(vault)

  -- One starting collector with BT
  local c = comps.new_collector({ x = 160, y = 120 })
  bt_defs.attach_collector_bt(c, vault)
  M.world:add(c)

  -- Ensure systems/entities are registered before first draw
  M.world:refresh()
end

function M.update(dt)
  if M.world then M.world:update(dt) end
end

function M.draw()
  if not M.world then return end
  -- Let any renderer systems draw
  for i = 1, #M.world.systems do
    local s = M.world.systems[i]
    if s and s.draw then s:draw() end
  end
end

return M
