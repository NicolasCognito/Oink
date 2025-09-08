local avatar = require('avatar')

local layerOrder = {
  background = 0,
  zones = 100,
  world = 200,
  overlay = 800,
  ui = 1000,
}

local function gather_drawcalls(world)
  local calls = {}
  local function push(layer, order, fn)
    calls[#calls+1] = { layer = layer, order = order or 0, fn = fn }
  end
  for i = 1, #world.entities do
    local e = world.entities[i]
    if e then
      if e.draw_handlers then
        for j = 1, #e.draw_handlers do
          local h = e.draw_handlers[j]
          if h and h.draw then
            push(h.layer or 'world', h.order or 0, function() h.draw(e, love.graphics, { world = world }) end)
          end
        end
      end
    end
  end
  return calls
end

local function sort_calls(a, b)
  local la = layerOrder[a.layer] or 0
  local lb = layerOrder[b.layer] or 0
  if la ~= lb then return la < lb end
  if a.order ~= b.order then return a.order < b.order end
  return false
end

local M = {}

function M.draw(world)
  if not world or not world.entities then return end
  local calls = gather_drawcalls(world)
  table.sort(calls, sort_calls)
  for i = 1, #calls do calls[i].fn() end

  -- UI: active entity label and position
  local active = avatar.get(world)
  if active and active.pos then
    local who = active.label or 'Entity'
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(who .. string.format(' (x=%.0f,y=%.0f)', active.pos.x, active.pos.y), 10, 10)
  end

  -- UI: Active controller inventory HUD at bottom (fallback to first player)
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

  -- UI: Slot inspector
  do
    local holder2 = avatar.get(world)
    if not holder2 then
      for i = 1, #world.entities do
        local e = world.entities[i]
        if e and e.player and e.inventory then holder2 = e; break end
      end
    end
    if holder2 and holder2.inventory then
      local inv = holder2.inventory
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
