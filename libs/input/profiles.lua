local H_character = require('input.handlers.character')
local H_inventory = require('input.handlers.inventory')
local H_mount = require('input.handlers.mount')
local H_vehicle = require('input.handlers.vehicle')

local M = {}

local function has_handler(e, kind)
  if not e or not e.input_handlers then return false end
  for i = 1, #e.input_handlers do
    local h = e.input_handlers[i]
    if h and h.kind == kind then return true end
  end
  return false
end

local function add(e, h)
  e.input_handlers = e.input_handlers or {}
  e.input_handlers[#e.input_handlers+1] = h
end

function M.ensure(e)
  if not e then return end
  -- Movement
  if e.controllable and e.pos and e.vel then
    if e.car then
      if not has_handler(e, 'vehicle') then
        add(e, H_vehicle({
          accel = e.accel or 220,
          max_speed = e.max_speed or 200,
          turn_rate = e.turn_rate or math.pi,
          friction = e.friction or 150,
        }))
      end
    else
      if not has_handler(e, 'character') then
        add(e, H_character({ speed = e.speed }))
      end
    end
  end
  -- Inventory
  if e.inventory and not has_handler(e, 'inventory') then
    add(e, H_inventory({}))
  end
  -- Mount toggle for players
  if e.player and not has_handler(e, 'mount') then
    add(e, H_mount({}))
  end
end

return M

