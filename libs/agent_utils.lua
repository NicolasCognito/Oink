local Coin = require('components.coin')

local M = {}

-- Drop coins from an agent's inventory into the world.
-- For collectors that only collect coins, we drop one coin per value point to preserve total value.
-- opts: { pos = {x,y} or rect = {x,y,w,h}, jitter = number }
function M.drop_coins(agent, world, opts)
  opts = opts or {}
  local inv = agent.inventory
  if not inv or (inv.value or 0) <= 0 then return 0 end
  local n = inv.value or inv.count or 0
  local jitter = opts.jitter or 2
  local function pick_pos()
    if opts.rect then
      local r = opts.rect
      return r.x + math.random() * r.w, r.y + math.random() * r.h
    end
    local px = (opts.pos and opts.pos.x) or (agent.pos and agent.pos.x) or 0
    local py = (opts.pos and opts.pos.y) or (agent.pos and agent.pos.y) or 0
    return px + (math.random()*2-1)*jitter, py + (math.random()*2-1)*jitter
  end
  for i = 1, n do
    local x, y = pick_pos()
    world:add(Coin.new(x, y, { value = 1 }))
  end
  -- Clear inventory counts/values for coins
  if inv.items then inv.items['coin'] = 0 end
  inv.count = 0
  inv.value = 0
  return n
end

return M

