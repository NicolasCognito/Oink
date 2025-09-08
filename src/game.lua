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
local Citizen = require('components.citizen')
local Miner = require('components.miner')
local TokenMiner = require('components.token_miner')
local BearTrap = require('Zones.bear_trap')
local Vault = require('Zones.vault')
local Chicken = require('components.chicken')
local TimeDistortion = require('Zones.time_distortion')
local TimeVortex = require('Zones.time_vortex')
local MainHall = require('Zones.main_hall')
local Teleport = require('Zones.teleport')
local EmptyArea = require('Zones.empty_area')
local Mine = require('Zones.mine')
local Home = require('Zones.home')
local TokenMine = require('Zones.token_mine')
local Shop = require('Zones.shop')
local Car = require('components.car')

local M = {}

function M.load()
  M.world = World.create()
  -- Two-player demo: Player1 is active by default, Player2 is eligible
  M.player = Player.new({ x = 60, y = 60, speed = 160, radius = 6, label = 'Player 1' })
  M.player.controlled = true
  M.world:add(M.player)
  M.player2 = Player.new({ x = 120, y = 60, speed = 160, radius = 6, label = 'Player 2' })
  M.player2.controlled = false
  M.world:add(M.player2)
  -- Add a zombie to demonstrate FSM behavior
  M.zombie = Zombie.new({ x = 260, y = 120, speed = 60, radius = 6, label = 'Zombie' })
  M.world:add(M.zombie)
  -- Add a second zombie and make it collectable (for testing generic collection)
  M.zombie2 = Zombie.new({ x = 320, y = 140, speed = 60, radius = 6, label = 'LootZombie' })
  M.zombie2.collectable = { name = 'zombie', value = 5, persistent = true }
  M.world:add(M.zombie2)
  -- Add a tax collector agent
  M.collector = TaxCollector.new({ x = 160, y = 160, speed = 120, radius = 6, label = 'Collector' })
  M.world:add(M.collector)
  -- Add a citizen composed of Tax Collector + Vacationer behaviors
  local TaxFSM = require('FSMs.tax_collector')
  M.citizen = Citizen.new({
    x = 200, y = 140, speed = 120, radius = 6, label = 'Citizen (Tax)',
    work_def = TaxFSM,
    collector = true, inventory_cap = 5,
    fatigue_rate = 1.2, rest_rate = 4.0, fatigue_max = 8, fatigue_min = 2,
  })
  M.world:add(M.citizen)
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
  -- Add a single time vortex zone with two modes (Stasis/Haste)
  M.vortex = TimeVortex.new(150, 100, 70, 50, {
    modes = {
      { name = 'Stasis', scale = 0.3 },
      { name = 'Haste',  scale = 2.5 },
    }
  })
  M.vortex.on_tick = TimeVortex.on_tick
  M.vortex.on_mode_switch = TimeVortex.on_mode_switch
  M.world:add(M.vortex)
  -- Add a main hall zone
  M.hall = MainHall.new(20, 240, 80, 32, { label = 'Main Hall' })
  M.hall.on_tick = MainHall.on_tick
  M.hall.on_mode_switch = MainHall.on_mode_switch
  M.world:add(M.hall)
  -- Add an empty area that can be transformed via M/T/V
  M.empty = EmptyArea.new(220, 240, 80, 32, { label = 'Empty (M/T/V)' })
  M.world:add(M.empty)
  -- Add a home zone for citizens to sleep
  M.home = Home.new(420, 240, 60, 36, { label = 'Home' })
  M.home.on_tick = Home.on_tick
  M.world:add(M.home)
  -- Add a teleport zone demo
  M.tele = Teleport.new(360, 60, 40, 40, { label = 'Teleport → (80,220)', tx = 80, ty = 220 })
  M.tele.on_tick = Teleport.on_tick
  M.world:add(M.tele)
  -- Add a mine zone and a miner
  M.mine = Mine.new(300, 200, 60, 40, { label = 'Mine', production_interval = 0.8, production_radius = 12 })
  M.mine.on_tick = Mine.on_tick
  M.world:add(M.mine)
  M.miner = Miner.new({ x = 320, y = 180, speed = 80, radius = 6, label = 'Miner' })
  M.world:add(M.miner)
  -- Add a token-mine and a citizen working as token-miner
  M.tmine = TokenMine.new(380, 200, 60, 40, { label = 'Token Mine', work_to_ruby = 3, process_interval = 0.4, give_interval = 1.0 })
  M.tmine.on_tick = TokenMine.on_tick
  M.world:add(M.tmine)
  M.token_citizen = Citizen.new({
    x = 400, y = 180, speed = 80, radius = 6,
    label = 'Citizen (TokenMiner)',
    work_def = require('FSMs.token_miner'),
    -- fatigue profile so they work most of the time
    fatigue_rate = 0.8, rest_rate = 3.0, fatigue_max = 8, fatigue_min = 2,
  })
  M.world:add(M.token_citizen)
  -- Add a car at the right-bottom area for driving demo
  M.car = Car.new({ x = 460, y = 260, radius = 10, label = 'Car' })
  M.world:add(M.car)

  -- Add a Shop zone in an unused screen area (top-right by default)
  do
    local W = (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 800
    local H = (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 600
    local zw, zh = 80, 40
    local zx = math.max(20, W - (zw + 20))
    local zy = 60
    M.shop = Shop.new(zx, zy, zw, zh, { label = 'Shop' })
    M.shop.on_tick = Shop.on_tick
    M.world:add(M.shop)
  end
end

function M.update(dt)
  if M.world then M.world:update(dt) end
end

function M.draw()
  if M.world then Draw.draw(M.world) end
end

return M
