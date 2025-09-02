local M = {}

local function default_draw_entity(e)
  if not e.pos or not e.drawable then return end
  local r = e.radius or 6
  if e.color then love.graphics.setColor(e.color) end
  love.graphics.circle('fill', e.pos.x, e.pos.y, r)
  love.graphics.setColor(1,1,1,1)
end

function M.draw(world)
  if not world or not world.entities then return end
  -- Draw zones (rectangles) first
  for i = 1, #world.entities do
    local z = world.entities[i]
    if z and z.zone and z.rect then
      if z.active ~= false then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.6)
      else
        love.graphics.setColor(0.4, 0.4, 0.4, 0.4)
      end
      love.graphics.rectangle('line', z.rect.x, z.rect.y, z.rect.w, z.rect.h)
      love.graphics.setColor(1,1,1,1)
      if z.label then
        love.graphics.print(z.label, z.rect.x + 2, z.rect.y - 14)
      end
    end
  end
  -- Draw entities (circles)
  for i = 1, #world.entities do
    local e = world.entities[i]
    if e then
      default_draw_entity(e)
    end
  end
  -- Example HUD: draw first controllable entity label/pos
  for i = 1, #world.entities do
    local e = world.entities[i]
    if e and e.label and e.pos then
      love.graphics.print(e.label .. string.format(' (x=%.0f,y=%.0f)', e.pos.x, e.pos.y), 10, 10)
      break
    end
  end
end

return M
