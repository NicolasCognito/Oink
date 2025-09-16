local fsm = require('tiny-fsm')
local comps = require('sim.components')
local bt_defs = require('sim.bt_defs')
local C = require('config')

local M = {}

-- Register vault actions once
local registered = false
local function ensure_registered()
  if registered then return end
  registered = true

  -- Spawn collectors when enough coins are available
  fsm.register_action('VaultSpawn', {
    update = function(ctx, dt)
      local v = ctx.entity
      local world = ctx.world
      while (v.coin_count or 0) >= (v.spawn_cost or C.vault.spawn_cost) do
        v.coin_count = v.coin_count - (v.spawn_cost or C.vault.spawn_cost)
        local e = comps.new_collector({ x = v.pos.x, y = v.pos.y, base_speed = C.collector.base_speed })
        bt_defs.attach_collector_bt(e, v)
        world:addEntity(e)
      end
    end,
  })

  -- Override collector speed globally via globals singleton
  fsm.register_action('VaultSpeedOverride', {
    enter = function(ctx) end,
    update = function(ctx)
      local world = ctx.world
      -- find globals; if not present create one
      local g = nil
      for _, e in ipairs(world.entities) do
        if e.globals then g = e; break end
      end
      if not g then
        g = comps.new_globals()
        world:addEntity(g)
      end
      g.override_speed_active = true
      g.override_speed = ctx.entity.override_speed or C.vault.override_speed
    end,
    exit = function(ctx)
      -- disable override
      local world = ctx.world
      for _, e in ipairs(world.entities) do
        if e.globals then e.override_speed_active = false end
      end
    end,
  })

  -- Boost coin spawn rate while active
  fsm.register_action('VaultSpawnrateBoost', {
    enter = function(ctx) end,
    update = function(ctx)
      local world = ctx.world
      for _, e in ipairs(world.entities) do
        if e.coin_spawner then
          e.rate_multiplier = ctx.entity.spawn_rate_multiplier or C.vault.spawn_rate_multiplier
        end
      end
    end,
    exit = function(ctx)
      local world = ctx.world
      for _, e in ipairs(world.entities) do
        if e.coin_spawner then e.rate_multiplier = 1.0 end
      end
    end,
  })
end

-- Build a simple machine matching vault.mode string
local function machine_for_mode(mode)
  return fsm.build({
    initial = mode,
    states = {
      spawn = { action = 'VaultSpawn' },
      speed = { action = 'VaultSpeedOverride' },
      spawnrate = { action = 'VaultSpawnrateBoost' },
    },
  })
end

function M.attach_vault_fsm(vault)
  ensure_registered()
  local m = machine_for_mode(vault.mode or 'spawn')
  vault.fsm = fsm.instance(m, { tick_interval = nil, name = 'VaultFSM' })
end

return M
