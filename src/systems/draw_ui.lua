package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')

return function(opts)
  opts = opts or {}
  local sys = tiny.system()
  sys.kind = 'draw_ui'

  -- Toggles
  sys.show_active_label = opts.show_active_label or false
  sys.show_inventory = opts.show_inventory ~= false
  sys.show_slot_inspector = opts.show_slot_inspector or false
  sys._prev = {}

  local function keydown(k)
    return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(k)
  end

  local function on_edge(self, key)
    local d = keydown(key)
    local was = self._prev[key] or false
    self._prev[key] = d
    return d and not was
  end

  function sys:update(dt)
    -- Toggle via function keys (extendable up to F12)
    if on_edge(self, 'f1') then self.show_active_label = not self.show_active_label end
    if on_edge(self, 'f2') then self.show_inventory = not self.show_inventory end
    if on_edge(self, 'f3') then self.show_slot_inspector = not self.show_slot_inspector end
  end

  function sys:draw()
    local world = self.world
    if not world then return end
    local gfx = love and love.graphics
    if not gfx then return end

    -- Active entity label
    if self.show_active_label then
      local active = avatar.get(world)
      if active and active.pos then
        local who = active.label or 'Entity'
        gfx.setColor(1,1,1,1)
        gfx.print(who .. string.format(' (x=%.0f,y=%.0f)', active.pos.x, active.pos.y), 10, 10)
      end
    end

    -- Inventory HUD
    if self.show_inventory then
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
        local h = (gfx.getHeight and gfx.getHeight()) or 300
        gfx.setColor(1,1,1,1)
        gfx.print(text, 10, h - 16)
      end
    end

    -- Slot inspector
    if self.show_slot_inspector then
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
        gfx.setColor(1,1,1,1)
        local y = 26
        gfx.print('Slot Inspector:', 10, y); y = y + 14
        gfx.print(string.format('Active: %d  permanent=%s reserved=%s default=%s', idx, tostring(s and s.permanent or false), tostring(s and s.reserved or false), tostring(s and s.default_name or '')), 10, y); y = y + 14
        if s then
          gfx.print(string.format('Slot name=%s count=%s value=%s', tostring(s.name), tostring(s.count or 0), tostring(s.value or 0)), 10, y); y = y + 14
          if s.entity then
            local e = s.entity
            gfx.print('Item type: entity', 10, y); y = y + 14
            if e.label then gfx.print('Label: '..tostring(e.label), 10, y); y = y + 14 end
            local flags = {}
            for _, k in ipairs({'agent','player','driver','collector','car','zone'}) do
              if e[k] then flags[#flags+1] = k end
            end
            gfx.print('Flags: '.. ( (#flags>0) and table.concat(flags, ',') or '-' ), 10, y); y = y + 14
            if e.collectable then
              local c = e.collectable
              gfx.print(string.format('Collectable: name=%s value=%s persistent=%s channel=%s', tostring(c.name), tostring(c.value or 0), tostring(c.persistent or false), tostring(c.channel or '')), 10, y); y = y + 14
            end
            if e.pos then
              gfx.print(string.format('Pos: x=%.1f y=%.1f r=%s', e.pos.x or 0, e.pos.y or 0, tostring(e.radius or '-')), 10, y); y = y + 14
            end
          else
            gfx.print('Item type: record', 10, y); y = y + 14
            gfx.print(string.format('Record: name=%s count=%s value=%s', tostring(s.name), tostring(s.count or 0), tostring(s.value or 0)), 10, y); y = y + 14
          end
          if type(s.accept) == 'function' then
            gfx.print('Slot has accept policy (function)', 10, y); y = y + 14
          end
        else
          gfx.print('No slot at this index', 10, y)
        end
      end
    end
  end

  return sys
end
