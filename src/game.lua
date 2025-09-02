package.path = table.concat({
  package.path,
  'src/?.lua','src/?/init.lua',
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local World = require('world')
local Player = require('components.player')
local Draw = require('systems.draw')
local Zombie = require('components.zombie')

local M = {}

function M.load()
  M.world = World.create()
  M.player = Player.new({ x = 60, y = 60, speed = 160, radius = 6, label = 'Player' })
  M.world:add(M.player)
  -- Add a zombie to demonstrate FSM behavior
  M.zombie = Zombie.new({ x = 260, y = 120, speed = 60, radius = 6, label = 'Zombie' })
  M.world:add(M.zombie)
end

function M.update(dt)
  if M.world then M.world:update(dt) end
end

function M.draw()
  if M.world then Draw.draw(M.world) end
end

return M
