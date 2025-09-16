require('spec.support.love_stub')
package.path = table.concat({
  package.path,
  'src/?.lua','src/?/init.lua',
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
}, ';')

local tiny = require('tiny')
local World = require('world')
local comps = require('sim.components')
local bt_defs = require('sim.bt_defs')
local fsm_defs = require('sim.fsm_defs')

describe('Coin/Collector/Vault simulation', function()
  it('collector picks a coin and deposits to vault', function()
    local world = World.create()
    math.randomseed(1)
    -- setup
    local globals = comps.new_globals(); world:add(globals)
    local spawner = comps.new_spawner(); world:add(spawner)
    local vault = comps.new_vault({ x = 0, y = 0 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    local c = comps.new_collector({ x = 10, y = 0 }); bt_defs.attach_collector_bt(c, vault); world:add(c)
    local coin = comps.new_coin({ x = 12, y = 0, value = 1 }); world:add(coin)

    -- run a few frames
    for i=1,120 do world:update(1/60) end
    assert.is_true((vault.coin_count or 0) >= 1)
  end)

  it('speed override mode applies to collectors', function()
    local world = World.create()
    local globals = comps.new_globals(); world:add(globals)
    local spawner = comps.new_spawner(); world:add(spawner)
    local vault = comps.new_vault({ x = 0, y = 0, mode = 'speed', override_speed = 200 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    local c = comps.new_collector({ x = 0, y = 0, base_speed = 50 }); bt_defs.attach_collector_bt(c, vault); world:add(c)

    -- tick once to apply FSM effects and speed system
    world:update(0)
    assert.equals(200, c.collector.speed)
  end)

  it('spawnrate mode boosts spawner rate', function()
    local world = World.create()
    local globals = comps.new_globals(); world:add(globals)
    local spawner = comps.new_spawner(); world:add(spawner)
    local vault = comps.new_vault({ x = 0, y = 0, mode = 'spawnrate', spawn_rate_multiplier = 3.0 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)

    world:update(0)
    assert.is_true(spawner.rate_multiplier >= 3.0)
  end)

  it('spawn mode consumes 15 coins to spawn collector', function()
    local world = World.create()
    local globals = comps.new_globals(); world:add(globals)
    local spawner = comps.new_spawner(); world:add(spawner)
    local vault = comps.new_vault({ x = 0, y = 0, mode = 'spawn', spawn_cost = 15 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    -- grant coins
    vault.coin_count = 30
    -- before
    local before = 0
    for _, e in ipairs(world.entities) do if e.collector then before = before + 1 end end
    -- update should spawn two collectors, consume 30 (needs one extra tick to realize new entities)
    world:update(0)
    world:update(0)
    local after = 0
    for _, e in ipairs(world.entities) do if e.collector then after = after + 1 end end
    assert.is_true(after >= before + 2)
    assert.equals(0, vault.coin_count)
  end)
end)
