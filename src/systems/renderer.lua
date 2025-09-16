local tiny = require('tiny')

local function draw_world(self)
  if not love or not love.graphics then return end
  local g = love.graphics
  local major = (love.getVersion and select(1, love.getVersion())) or 11
  local function col(r, g1, b, a)
    if major < 11 then
      g.setColor(r * 255, g1 * 255, b * 255, (a or 1) * 255)
    else
      g.setColor(r, g1, b, a)
    end
  end
  if major < 11 then
    g.clear(0.08 * 255, 0.08 * 255, 0.1 * 255, 255)
  else
    g.clear(0.08, 0.08, 0.1)
  end
  col(1,1,1,1)
  g.print('Space: switch Vault mode', 10, 10)

  -- Find vault
  local vault
  for _, e in ipairs(self.world.entities) do if e.vault then vault = e; break end end
  if vault then
    col(0.2, 0.8, 0.9, 1)
    g.rectangle('line', vault.pos.x-16, vault.pos.y-12, 32, 24)
    col(1,1,1,1)
    g.print(('Vault: %s  Coins: %d'):format(vault.mode or 'spawn', vault.coin_count or 0), vault.pos.x+20, vault.pos.y-10)
  end

  -- Draw coins
  for _, e in ipairs(self.world.entities) do
    if e.coin and e.pos then
      col(1, 0.9, 0.1, 1)
      g.circle('fill', e.pos.x, e.pos.y, 4)
    end
  end

  -- Draw collectors
  for _, e in ipairs(self.world.entities) do
    if e.collector and e.pos then
      col(0.3, 0.6, 1.0, 1)
      g.circle('fill', e.pos.x, e.pos.y, 6)
      if e.carrying and e.carrying ~= false then
        col(0.9, 0.9, 0.2, 1)
        g.circle('fill', e.pos.x+8, e.pos.y-8, 3)
      end
    end
  end
end

return function()
  local sys = { name = 'RendererSystem', kind = 'renderer', nocache = true }
  function sys:onAddToWorld(world) self.world = world end
  function sys:draw() draw_world(self) end
  return sys
end
