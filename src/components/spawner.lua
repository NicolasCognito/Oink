local C = require('config')

local M = {}

function M.new(opts)
  opts = opts or {}
  return {
    coin_spawner = true,
    interval = opts.interval or C.spawner.interval,
    acc = 0,
    rate_multiplier = opts.rate_multiplier or 1.0,
    area = opts.area or C.spawner.area,
    max_alive = opts.max_alive or C.spawner.max_alive,
  }
end

return M

