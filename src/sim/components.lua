local C = require('config')

local M = {}

function M.new_globals()
  return {
    globals = true,
    override_speed_active = false,
    override_speed = C.vault.override_speed,
  }
end

function M.new_vault(opts)
  opts = opts or {}
  return {
    vault = true,
    pos = { x = opts.x or 100, y = opts.y or 100 },
    coin_count = opts.coin_count or 0,
    mode = opts.mode or 'spawn', -- 'spawn' | 'speed' | 'spawnrate'
    spawn_cost = opts.spawn_cost or C.vault.spawn_cost,
    override_speed = opts.override_speed or C.vault.override_speed,
    spawn_rate_multiplier = opts.spawn_rate_multiplier or C.vault.spawn_rate_multiplier,
  }
end

function M.new_collector(opts)
  opts = opts or {}
  local base = opts.base_speed or C.collector.base_speed
  return {
    collector = { base_speed = base, speed = base },
    pos = { x = opts.x or 0, y = opts.y or 0 },
    carrying = false, -- or { value = number }
    target_coin = nil,
  }
end

function M.new_coin(opts)
  opts = opts or {}
  return {
    coin = { value = opts.value or 1 },
    pos = { x = opts.x or 0, y = opts.y or 0 },
  }
end

function M.new_spawner(opts)
  opts = opts or {}
  return {
    coin_spawner = true,
    interval = opts.interval or C.spawner.interval,
    acc = 0,
    rate_multiplier = 1.0,
    area = opts.area or C.spawner.area,
    max_alive = opts.max_alive or C.spawner.max_alive,
  }
end

function M.new_input()
  return {
    input = true,
    space_was_down = false,
  }
end

return M
