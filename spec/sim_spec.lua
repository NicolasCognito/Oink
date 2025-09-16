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

  it('spawn mode consumes 3 coins to spawn collector', function()
    local world = World.create()
    local globals = comps.new_globals(); world:add(globals)
    local spawner = comps.new_spawner(); world:add(spawner)
    local vault = comps.new_vault({ x = 0, y = 0, mode = 'spawn', spawn_cost = 3 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
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

describe('Gamer-focused behaviors', function()
  it('two collectors do not chase the same coin when alternatives exist', function()
    local world = World.create()
    world:add(comps.new_globals())
    world:add(comps.new_spawner({ max_alive = 100 }))
    local vault = comps.new_vault({ x = 0, y = 0 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    local c1 = comps.new_collector({ x = -10, y = 0 }); local c2 = comps.new_collector({ x = 10, y = 0 })
    require('sim.bt_defs').attach_collector_bt(c1, vault)
    require('sim.bt_defs').attach_collector_bt(c2, vault)
    world:add(c1); world:add(c2)
    local coin1 = comps.new_coin({ x = -12, y = 0 }); local coin2 = comps.new_coin({ x = 12, y = 0 })
    world:add(coin1); world:add(coin2)
    -- Let targeting run
    world:update(0)
    assert.is_true(c1.target_coin == coin1 or c1.target_coin == coin2)
    assert.is_true(c2.target_coin == coin1 or c2.target_coin == coin2)
    assert.not_equal(c1.target_coin, c2.target_coin)
  end)

  it('retargets when coin disappears mid-chase', function()
    local world = World.create()
    world:add(comps.new_globals())
    world:add(comps.new_spawner({}))
    local vault = comps.new_vault({ x = 0, y = 0 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    local c = comps.new_collector({ x = 0, y = 0 }); require('sim.bt_defs').attach_collector_bt(c, vault); world:add(c)
    local coinA = comps.new_coin({ x = 50, y = 0 }); local coinB = comps.new_coin({ x = 200, y = 0 })
    world:add(coinA); world:add(coinB)
    world:update(0)
    assert.is_truthy(c.target_coin)
    -- remove the targeted coin
    local doomed = c.target_coin; world:removeEntity(doomed); doomed._dead = true
    -- allow retarget
    for i=1,10 do world:update(1/60) end
    assert.is_truthy(c.target_coin)
    assert.not_equal(c.target_coin, doomed)
  end)

  it('retargets if a fool steals a targeted coin', function()
    math.randomseed(7)
    local world = World.create()
    world:add(comps.new_globals())
    world:add(comps.new_spawner({}))
    local vault = comps.new_vault({ x = 0, y = 0 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    local c = comps.new_collector({ x = 0, y = 0 }); require('sim.bt_defs').attach_collector_bt(c, vault); world:add(c)
    local fool = comps.new_fool({ x = 45, y = 0, speed = 0, always_pick = true }); world:add(fool)
    local coinA = comps.new_coin({ x = 50, y = 0 }); local coinB = comps.new_coin({ x = 60, y = 0 })
    world:add(coinA); world:add(coinB)
    world:update(0)
    assert.is_truthy(c.target_coin)
    -- Fool steals coinA (always_pick=true)
    for i=1,2 do world:update(1/60) end
    -- After some ticks collector should not chase a dead coin; may have a new target or none
    if not (c.carrying and c.carrying ~= false) then
      if c.target_coin ~= nil then
        assert.is_truthy(c.target_coin.pos)
        assert.is_true(not c.target_coin._dead)
        assert.is_true(c.target_coin == coinA and coinA._dead or c.target_coin ~= coinA)
      end
    end
  end)

  it('respects spawner max_alive cap', function()
    local world = World.create()
    local sp = comps.new_spawner({ interval = 0.01, max_alive = 3 })
    world:add(sp)
    world:update(1.0)
    -- count coins
    local coins=0; for _,e in ipairs(world.entities) do if e.coin then coins=coins+1 end end
    assert.is_true(coins <= 3)
  end)

  it('spawnrate mode noticeably increases coin spawns over time', function()
    local function count_after_mode(mode)
      local w = World.create(); w:add(comps.new_globals()); local sp = comps.new_spawner({ interval=0.1, max_alive=1000 }); w:add(sp)
      local v = comps.new_vault({ x=0, y=0, mode = mode, spawn_rate_multiplier = 3.0 }); fsm_defs.attach_vault_fsm(v); w:add(v)
      for i=1,60 do w:update(1/60) end
      local c=0; for _,e in ipairs(w.entities) do if e.coin then c=c+1 end end; return c
    end
    local base = count_after_mode('spawn')
    local boosted = count_after_mode('spawnrate')
    assert.is_true(boosted >= base * 2)
  end)

  it('speed mode applies to future collectors too', function()
    local world = World.create()
    world:add(comps.new_globals())
    world:add(comps.new_spawner())
    local vault = comps.new_vault({ x=0,y=0, mode='speed', override_speed=180 }); fsm_defs.attach_vault_fsm(vault); world:add(vault)
    world:update(0)
    local c = comps.new_collector({ x = 0, y = 0 })
    require('sim.bt_defs').attach_collector_bt(c, vault); world:add(c)
    world:update(0)
    assert.equals(180, c.collector.speed)
  end)
end)
