local Mine = require('Zones.mine')
local TimeVortex = require('Zones.time_vortex')
local TimeDistortion = require('Zones.time_distortion')
local Vault = require('Zones.vault')
local Home = require('Zones.home')
local Arcade = require('Zones.arcade')
local Teleport = require('Zones.teleport')
local H_zone_mode = require('input.handlers.zone_mode')

local on_input

-- Build templates: function returning a zone instance
local templates = {
  { name = 'Mine', build = function(x,y,w,h)
      local z = Mine.new(x, y, w, h, { label = 'Mine' })
      z.on_tick = Mine.on_tick
      return z
    end },
  { name = 'Time Vortex', build = function(x,y,w,h)
      local z = TimeVortex.new(x, y, w, h, { modes = {
        { name = 'Stasis', scale = 0.3 },
        { name = 'Haste',  scale = 2.5 },
      }})
      z.on_tick = TimeVortex.on_tick
      return z
    end },
  { name = 'Vault', build = function(x,y,w,h)
      local z = Vault.new(x, y, w, h, { label = 'Vault' })
      z.on_tick = Vault.on_tick
      return z
    end },
  { name = 'Home', build = function(x,y,w,h)
      local z = Home.new(x, y, w, h, { label = 'Home' })
      z.on_tick = Home.on_tick
      return z
    end },
  { name = 'Arcade', build = function(x,y,w,h)
      local z = Arcade.new(x, y, w, h, { label = 'Arcade (G: Pong)' })
      -- arcade handles its own input; no on_tick needed
      return z
    end },
  { name = 'Teleport', build = function(x,y,w,h)
      local z = Teleport.new(x, y, w, h, { label = 'Teleport [ON] (L=TP, R=Panel)', tx = x + w + 40, ty = y + h + 20 })
      z.on_tick = Teleport.on_tick
      z.on_input = Teleport.on_input
      return z
    end },
  { name = 'Slow', build = function(x,y,w,h)
      local z = TimeDistortion.new(x, y, w, h, { label = 'Slow', factor = 0.5 })
      z.on_tick = TimeDistortion.on_tick
      return z
    end },
}

local function new_empty_area(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'empty_area',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    drawable = true,
    input_priority = opts.input_priority or 1,
    modes = opts.modes or templates,
  }
  -- Label shows current selection and hints
  local function apply_label(cur)
    local name = (cur and cur.name) or 'None'
    z.label = string.format('Build: %s (Q/E switch, B build)', name)
  end
  z.on_mode_change = function(zone, prev, nextm)
    apply_label(nextm)
  end
  apply_label(z.modes and z.modes[1])
  -- Attach mode rotate handler
  z.input_handlers = z.input_handlers or {}
  table.insert(z.input_handlers, H_zone_mode({ repeat_rate = 0.25 }))

  -- Also support direct single-key transforms for backward compatibility
  z.on_input = function(zone, input, ctx)
    return on_input(zone, input, ctx)
  end
  return z
end

function on_input(zone, input, ctx)
  if zone.active == false then return end
  local x, y, w, h = zone.rect.x, zone.rect.y, zone.rect.w, zone.rect.h
  local world = ctx and ctx.world
  if not world then return end
  local replace = nil

  -- New flow: press B or Enter to build current mode
  if input.pressed('b') or input.pressed('return') then
    local cur = zone.modes and zone.modes[1]
    if cur and cur.build then
      replace = cur.build(x, y, w, h)
    end
  end

  -- Back-compat: single key transforms
  if not replace then
    if input.pressed('m') then
      replace = templates[1].build(x, y, w, h)
    elseif input.pressed('t') then
      replace = templates[2].build(x, y, w, h)
    elseif input.pressed('v') then
      replace = templates[3].build(x, y, w, h)
    elseif input.pressed('h') then
      replace = templates[4].build(x, y, w, h)
    end
  end

  if replace then
    world:remove(zone)
    world:add(replace)
  end
end

return { new = new_empty_area, on_input = on_input }
