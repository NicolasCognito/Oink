local tiny = require('tiny')
local comps = require('sim.components')
local fsm_defs = require('sim.fsm_defs')

local function process(self, e, dt)
  local is_down = false
  if love and love.keyboard and love.keyboard.isDown then
    is_down = love.keyboard.isDown('space') and true or false
  end
  local was = e.space_was_down or false
  if is_down and not was then
    -- rising edge: switch vault mode in a cycle
    local modes = { 'spawn', 'speed', 'spawnrate' }
    -- find vault
    local vault
    for _, ent in ipairs(self.world.entities) do if ent.vault then vault = ent; break end end
    if vault then
      local cur = vault.mode or 'spawn'
      local idx = 1
      for i=1,#modes do if modes[i]==cur then idx=i; break end end
      local next_mode = modes[(idx % #modes) + 1]
      vault.mode = next_mode
      fsm_defs.attach_vault_fsm(vault)
    end
  end
  e.space_was_down = is_down
end

return function()
  local System = tiny.processingSystem()
  System.filter = tiny.requireAll('input')
  System.name = 'InputSystem'
  System.process = function(self, e, dt) return process(self, e, dt) end
  return System
end

