local tiny = require('tiny')

local function draw_world(self)
  if not love or not love.graphics then return end
  local g = love.graphics
  local major = (love.getVersion and select(1, love.getVersion())) or 11
  local function col(r, g1, b, a)
    if major < 11 then
      g.setColor((r or 1) * 255, (g1 or 1) * 255, (b or 1) * 255, (a or 1) * 255)
    else
      g.setColor(r or 1, g1 or 1, b or 1, a or 1)
    end
  end
  -- Set background color in a version-safe way
  if love.graphics.setBackgroundColor then
    if major < 11 then
      love.graphics.setBackgroundColor(0.08 * 255, 0.08 * 255, 0.1 * 255, 255)
    else
      love.graphics.setBackgroundColor(0.08, 0.08, 0.1, 1)
    end
  end
  -- Clear with current background color (works across versions)
  g.clear()
  col(1,1,1,1)
  g.print('Oink — minimal refactor (coins + move/task)', 10, 10)

  -- Find vault
  -- Vault/other UI removed in this phase

  -- Draw coins
  for _, e in ipairs(self.world.entities) do
    if e.coin and e.pos then
      col(1, 0.9, 0.1, 1)
      g.circle('fill', e.pos.x, e.pos.y, 4)
    end
  end

  -- Draw any entity that has pos but isn't a coin (as a white dot)
  for _, e in ipairs(self.world.entities) do
    if e.pos and not e.coin then
      col(1, 1, 1, 0.6)
      g.circle('line', e.pos.x, e.pos.y, 6)
    end
  end
end

return function()
  local tiny = require('tiny')
  local sys = tiny.system({ name = 'RendererSystem', kind = 'renderer', nocache = true })
  function sys:onAddToWorld(world) self.world = world end
  function sys:draw() draw_world(self) end
  return sys
end
