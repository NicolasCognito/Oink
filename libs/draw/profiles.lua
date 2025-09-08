local avatar = require('avatar')
local collision = require('collision')

local M = {}

local function has_handler(e, kind)
  local list = e.draw_handlers
  if not list then return false end
  for i = 1, #list do
    local h = list[i]
    if h and h.kind == kind then return true end
  end
  return false
end

local function add(e, handler)
  e.draw_handlers = e.draw_handlers or {}
  e.draw_handlers[#e.draw_handlers+1] = handler
end

local function zone_outline_handler()
  return {
    kind = 'zone_outline',
    layer = 'zones',
    order = 0,
    draw = function(zone, gfx, ctx)
      if not zone.rect then return end
      if zone.active ~= false then gfx.setColor(0.8, 0.2, 0.2, 0.6) else gfx.setColor(0.4, 0.4, 0.4, 0.4) end
      gfx.rectangle('line', zone.rect.x, zone.rect.y, zone.rect.w, zone.rect.h)
      if zone.colliders and #zone.colliders > 0 then
        gfx.setColor(0.9, 0.9, 0.2, 0.5)
        for ci = 1, #zone.colliders do
          local c = zone.colliders[ci]
          local kind = c.kind or 'rect'
          if kind == 'rect' then
            local x = zone.rect.x + (c.dx or 0)
            local y = zone.rect.y + (c.dy or 0)
            local w = c.w or 0
            local h = c.h or 0
            gfx.rectangle('line', x, y, w, h)
          elseif kind == 'circle' then
            local cx = zone.rect.x + (c.dx or 0)
            local cy = zone.rect.y + (c.dy or 0)
            local r = c.r or 0
            gfx.circle('line', cx, cy, r)
          end
        end
      end
      gfx.setColor(1,1,1,1)
      if zone.label then
        local label = zone.label
        if zone.modes and #zone.modes > 1 then
          local cur = zone.modes[1]
          local mname = (type(cur) == 'table' and cur.name) and tostring(cur.name) or nil
          if mname and #mname > 0 then
            label = label .. ':' .. mname
          end
        end
        gfx.print(label, zone.rect.x + 2, zone.rect.y - 14)
      end
    end,
  }
end

local function entity_circle_handler()
  return {
    kind = 'entity_circle',
    layer = 'world',
    order = 0,
    draw = function(e, gfx, ctx)
      if not e.pos or not e.drawable then return end
      local r = e.radius or 6
      if e.color then gfx.setColor(e.color) end
      gfx.circle('fill', e.pos.x, e.pos.y, r)
      gfx.setColor(1,1,1,1)
    end,
  }
end

function M.ensure(e)
  if not e then return end
  -- Zones
  if e.zone and e.rect and not has_handler(e, 'zone_outline') then
    add(e, zone_outline_handler())
  end
  -- Generic drawable entities
  if e.drawable and e.pos and not has_handler(e, 'entity_circle') then
    local has_custom_handlers = e.draw_handlers and (#e.draw_handlers > 0)
    local has_custom_draw = type(e.draw) == 'function'
    if (not has_custom_handlers and not has_custom_draw) or (e.draw_default == true) then
      add(e, entity_circle_handler())
    end
  end
  -- Shorthand: support e.draw single function (wrap once)
  if e.draw and not has_handler(e, 'custom_draw') then
    local layer = e.draw_layer or 'world'
    local order = e.draw_order or 0
    add(e, {
      kind = 'custom_draw', layer = layer, order = order,
      draw = function(entity, gfx, ctx) entity:draw(gfx, ctx) end
    })
  end
end

return M
