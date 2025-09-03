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
local TaxCollector = require('components.tax_collector')
local BearTrap = require('Zones.bear_trap')
local Vault = require('Zones.vault')
local Chicken = require('components.chicken')
local TimeDistortion = require('Zones.time_distortion')
local TimeVortex = require('Zones.time_vortex')
local MainHall = require('Zones.main_hall')

local M = {}

function M.load()
  M.world = World.create()
  M.player = Player.new({ x = 60, y = 60, speed = 160, radius = 6, label = 'Player' })
  M.world:add(M.player)
  -- Add a zombie to demonstrate FSM behavior
  M.zombie = Zombie.new({ x = 260, y = 120, speed = 60, radius = 6, label = 'Zombie' })
  M.world:add(M.zombie)
  -- Add a second zombie and make it collectable (for testing generic collection)
  M.zombie2 = Zombie.new({ x = 320, y = 140, speed = 60, radius = 6, label = 'LootZombie' })
  M.zombie2.collectable = { name = 'zombie', value = 5 }
  M.world:add(M.zombie2)
  -- Add a tax collector agent
  M.collector = TaxCollector.new({ x = 160, y = 160, speed = 120, radius = 6, label = 'Collector' })
  M.world:add(M.collector)
  -- Add a bear trap zone for testing
  M.trap = BearTrap.new(220, 100, 30, 30, { label = 'Trap' })
  M.trap.on_tick = BearTrap.on_tick
  M.world:add(M.trap)
  -- Add a vault zone to absorb coins (handled by zone_collect system)
  M.vault = Vault.new(40, 200, 40, 24, { label = 'Vault' })
  M.world:add(M.vault)
  -- Add a chicken agent
  M.chicken = Chicken.new({ x = 120, y = 60, egg_interval = 4, egg_ttl = 12, speed = 70 })
  M.world:add(M.chicken)
  -- Add a time distortion zone
  M.slow = TimeDistortion.new(260, 60, 40, 40, { label = 'Slow', factor = 0.5 })
  M.slow.on_tick = TimeDistortion.on_tick
  M.world:add(M.slow)
  -- Add time vortex zones (separate from speed changes)
  M.vortex_stasis = TimeVortex.new(100, 100, 50, 50, { label = 'Stasis', scale = 0.3 })
  M.vortex_stasis.on_tick = TimeVortex.on_tick
  M.world:add(M.vortex_stasis)
  M.vortex_haste = TimeVortex.new(200, 100, 50, 50, { label = 'Haste', scale = 2.5 })
  M.vortex_haste.on_tick = TimeVortex.on_tick
  M.world:add(M.vortex_haste)
  M.vortex_chaos = TimeVortex.new(300, 100, 50, 50, { label = 'Chaos', scale = 1.0 })
  M.vortex_chaos.on_tick = function(zone, snapshot)
    zone.scale = 0.1 + math.random() * 4.9
    TimeVortex.on_tick(zone, snapshot)
  end
  M.world:add(M.vortex_chaos)
  -- Add a main hall zone
  M.hall = MainHall.new(20, 240, 80, 32, { label = 'Main Hall' })
  M.hall.on_tick = MainHall.on_tick
  M.hall.on_mode_switch = MainHall.on_mode_switch
  M.world:add(M.hall)
end

function M.update(dt)
  if M.world then M.world:update(dt) end
end

function M.draw()
  if M.world then Draw.draw(M.world) end
end

return M
