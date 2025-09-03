local Mine = require('Zones.mine')
local TimeVortex = require('Zones.time_vortex')
local Vault = require('Zones.vault')

-- forward declare handler to allow reference in constructor
local on_key

local function new_empty_area(x, y, w, h, opts)
  opts = opts or {}
  local z = {
    zone = true,
    type = 'empty_area',
    active = opts.active ~= false,
    rect = { x = x or 0, y = y or 0, w = w or 48, h = h or 32 },
    label = opts.label or 'Empty Area (M=Mine, T=Time, V=Vault)',
    drawable = true,
  }
  z.on_key = function(zone, player, key, ctx)
    return on_key(zone, player, key, ctx)
  end
  return z
end

function on_key(zone, player, key, ctx)
  if zone.active == false then return end
  key = string.lower(key or '')
  local x, y, w, h = zone.rect.x, zone.rect.y, zone.rect.w, zone.rect.h
  local world = ctx and ctx.world
  if not world then return end

  local replace = nil
  if key == 'm' then
    replace = Mine.new(x, y, w, h, { label = 'Mine' })
    replace.on_tick = Mine.on_tick
  elseif key == 't' then
    replace = TimeVortex.new(x, y, w, h, { modes = {
      { name = 'Stasis', scale = 0.3 },
      { name = 'Haste',  scale = 2.5 },
    }})
    replace.on_tick = TimeVortex.on_tick
    replace.on_mode_switch = TimeVortex.on_mode_switch
  elseif key == 'v' then
    replace = Vault.new(x, y, w, h, { label = 'Vault' })
    replace.on_tick = Vault.on_tick
  end

  if replace then
    -- Swap zones
    world:remove(zone)
    world:add(replace)
  end
end

return { new = new_empty_area, on_key = on_key }
