local M = {}
local avatar = require('avatar')
local collision = require('collision')

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
  -- HUD: active entity label and position
  local active = avatar.get(world)
  if active and active.pos then
    local who = active.label or 'Entity'
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(who .. string.format(' (x=%.0f,y=%.0f)', active.pos.x, active.pos.y), 10, 10)
  end

  -- Active controller inventory HUD at bottom (fallback to first player)
  local holder = avatar.get(world)
  if not holder then
    for i = 1, #world.entities do
      local e = world.entities[i]
      if e and e.player then holder = e; break end
    end
  end
  if holder and holder.inventory then
    local inv = holder.inventory
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
    local who = holder.label or 'Entity'
    local text = who .. ' inv: ' .. table.concat(parts, '  ') .. summary
    local h = (love.graphics.getHeight and love.graphics.getHeight()) or 300
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(text, 10, h - 16)
  end

  -- Slot inspector: show detailed info about the selected slot of the active holder
  do
    local holder = avatar.get(world)
    if not holder then
      for i = 1, #world.entities do
        local e = world.entities[i]
        if e and e.player and e.inventory then holder = e; break end
      end
    end
    if holder and holder.inventory then
      local inv = holder.inventory
      local idx = inv.active_index or 1
      local s = inv.slots and inv.slots[idx]
      love.graphics.setColor(1,1,1,1)
      local y = 26
      love.graphics.print('Slot Inspector:', 10, y); y = y + 14
      love.graphics.print(string.format('Active: %d  permanent=%s reserved=%s default=%s', idx, tostring(s and s.permanent or false), tostring(s and s.reserved or false), tostring(s and s.default_name or '')), 10, y); y = y + 14
      if s then
        love.graphics.print(string.format('Slot name=%s count=%s value=%s', tostring(s.name), tostring(s.count or 0), tostring(s.value or 0)), 10, y); y = y + 14
        if s.entity then
          local e = s.entity
          love.graphics.print('Item type: entity', 10, y); y = y + 14
          if e.label then love.graphics.print('Label: '..tostring(e.label), 10, y); y = y + 14 end
          local flags = {}
          for _, k in ipairs({'agent','player','driver','collector','car','zone'}) do
            if e[k] then flags[#flags+1] = k end
          end
          love.graphics.print('Flags: '.. ( (#flags>0) and table.concat(flags, ',') or '-' ), 10, y); y = y + 14
          if e.collectable then
            local c = e.collectable
            love.graphics.print(string.format('Collectable: name=%s value=%s persistent=%s channel=%s', tostring(c.name), tostring(c.value or 0), tostring(c.persistent or false), tostring(c.channel or '')), 10, y); y = y + 14
          end
          if e.pos then
            love.graphics.print(string.format('Pos: x=%.1f y=%.1f r=%s', e.pos.x or 0, e.pos.y or 0, tostring(e.radius or '-')), 10, y); y = y + 14
          end
        else
          love.graphics.print('Item type: record', 10, y); y = y + 14
          love.graphics.print(string.format('Record: name=%s count=%s value=%s', tostring(s.name), tostring(s.count or 0), tostring(s.value or 0)), 10, y); y = y + 14
        end
        if type(s.accept) == 'function' then
          love.graphics.print('Slot has accept policy (function)', 10, y); y = y + 14
        end
      else
        love.graphics.print('No slot at this index', 10, y)
      end
    end
  end
end

return M
