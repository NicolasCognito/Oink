package.path = table.concat({
  package.path,
  'src/?.lua','src/?/init.lua',
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local World = require('world')
local bt = require('tiny-bt')
local pos = require('components.pos')
local vel = require('components.vel')
local spawner = require('components.spawner')
local task = require('components.task')
local compose = require('components.compose').compose

local M = {}

function M.load()
  M.world = World.create()
  math.randomseed(42)

  if love and love.window and love.window.setMode then
    love.window.setMode(800, 600, { resizable = false })
  end

  -- Spawner entity (prime it for immediate spawn)
  local s = spawner.new()
  s.acc = s.interval
  M.world:add(s)

  -- Demo collector agent driven by a data-only behavior tree
  local CollectorTree = require('BTs.collector')
  local ZombieTree = require('BTs.zombie')
  local CitizenTree = require('BTs.citizen')
  local collector1 = compose(pos.new(160, 120), vel.new(0, 0))
  collector1.bt = bt.instance(CollectorTree.build(), { name = 'CollectorBT_1' })
  M.world:add(collector1)

  -- Second collector
  local collector2 = compose(pos.new(640, 360), vel.new(0, 0))
  collector2.bt = bt.instance(CollectorTree.build(), { name = 'CollectorBT_2' })
  M.world:add(collector2)

  -- Citizen: flees zombies, otherwise works via profession subtree (collector)
  local citizen = compose(pos.new(320, 260), vel.new(0, 0))
  citizen.living = true
  citizen.profession = 'collector'
  citizen.speed = 140
  citizen.bt = bt.instance(CitizenTree.build({ sense_radius = 260, flee_distance = 140, flee_speed = 140 }), { name = 'CitizenBT_1' })
  M.world:add(citizen)

  -- Zombie: chases entities with tag `living` within sense radius
  local zombie = compose(pos.new(520, 200), vel.new(0, 0))
  zombie.zombie = true
  zombie.speed = 90
  zombie.bt = bt.instance(ZombieTree.build({ sense_radius = 200, speed = 90 }), { name = 'ZombieBT_1' })
  M.world:add(zombie)

  -- Ensure systems/entities are registered before first draw
  M.world:refresh()
end

function M.update(dt)
  if M.world then M.world:update(dt) end
end

function M.draw()
  if not M.world then return end
  if love and love.graphics then
    local g = love.graphics
    local major = (love.getVersion and select(1, love.getVersion())) or 11
    if love.graphics.setBackgroundColor then
      if major < 11 then love.graphics.setBackgroundColor(10, 10, 12, 255) else love.graphics.setBackgroundColor(0.04,0.04,0.05,1) end
    end
    g.clear()
    -- Fallback debug text so something always appears
    if major < 11 then g.setColor(255,255,255,255) else g.setColor(1,1,1,1) end
    g.print('Oink Sim — press Space to switch mode', 10, 10)
  end
  -- Let any renderer systems draw
  for i = 1, #M.world.systems do
    local s = M.world.systems[i]
    if s and s.draw then s:draw() end
  end
end

return M
