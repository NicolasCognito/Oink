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
      -- Base rect
      if z.active ~= false then love.graphics.setColor(0.8, 0.2, 0.2, 0.6) else love.graphics.setColor(0.4, 0.4, 0.4, 0.4) end
      love.graphics.rectangle('line', z.rect.x, z.rect.y, z.rect.w, z.rect.h)
      -- Sub-colliders (if any)
      if z.colliders and #z.colliders > 0 then
        love.graphics.setColor(0.9, 0.9, 0.2, 0.5)
        for ci = 1, #z.colliders do
          local c = z.colliders[ci]
          local kind = c.kind or 'rect'
          if kind == 'rect' then
            local x = z.rect.x + (c.dx or 0)
            local y = z.rect.y + (c.dy or 0)
            local w = c.w or 0
            local h = c.h or 0
            love.graphics.rectangle('line', x, y, w, h)
          elseif kind == 'circle' then
            local cx = z.rect.x + (c.dx or 0)
            local cy = z.rect.y + (c.dy or 0)
            local r = c.r or 0
            love.graphics.circle('line', cx, cy, r)
          end
        end
      end
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

  -- Player inventory HUD at bottom
  local player
  for i = 1, #world.entities do
    local e = world.entities[i]
    if e and e.player then player = e; break end
  end
  if player and player.inventory then
    local inv = player.inventory
    local parts = {}
    local cap = inv.cap or 9
    for i = 1, cap do
      local s = inv.slots and inv.slots[i]
      local label
      if s then
        label = string.format('%d:%s x%d', i, s.name, s.count or 1)
      else
        label = string.format('%d:-', i)
      end
      if inv.active_index == i then
        label = '['..label..']'
      end
      parts[#parts+1] = label
    end
    local summary = string.format('  |  Items:%d  Value:%.0f', inv.count or 0, inv.value or 0)
    local text = table.concat(parts, '  ') .. summary
    local h = (love.graphics.getHeight and love.graphics.getHeight()) or 300
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(text, 10, h - 16)
  end
end

return M
