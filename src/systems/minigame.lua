package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')

local function find_system(world, kind)
  if not world or not world.systems then return nil end
  for i = 1, #world.systems do
    local s = world.systems[i]
    if s and s.kind == kind then return s end
  end
  return nil
end

return function(opts)
  opts = opts or {}
  local sys = tiny.system()
  sys.kind = 'minigame'
  sys._active = false
  sys._name = nil
  sys._owner = nil
  sys._game = nil
  sys._scale = opts.scale or 2
  sys._bg = {0,0,0,0.45}

  function sys:onAddToWorld(world)
    self.world = world
  end

  -- Open a minigame.
  -- spec can be a string module name under minigames/, or a pre-constructed game table.
  -- Returns the game instance on success.
  function sys:open(spec, owner, params)
    params = params or {}
    -- Build a small bridge for bi-directional communication with the opener (owner)
    local bridge = params.bridge or {}
    bridge.owner = owner
    bridge.close = function()
      self:close(owner)
    end
    bridge.send = function(event, payload)
      if owner and owner.on_minigame_event then
        owner.on_minigame_event(owner, self, event, payload)
      end
    end
    params.bridge = bridge

    if type(spec) == 'table' then
      self._game = spec
      self._name = spec.name or 'custom'
    else
      local ok, mod = pcall(require, 'minigames.'..tostring(spec))
      if not ok or not mod or not mod.new then return nil, 'minigame not found: '..tostring(spec) end
      local w, h = 200, 140
      if params and params.w and params.h then w, h = params.w, params.h end
      self._game = mod.new(w, h, params)
      self._name = tostring(spec)
    end
    self._owner = owner
    self._active = self._game ~= nil
    -- Deactivate input system while a minigame is active
    if self._active then
      local input_sys = find_system(self.world, 'input')
      if input_sys then input_sys.active = false end
      self._esc_prev = false
    end
    -- Attach a relation on the owner for explicit two-way access
    if owner then
      owner.minigame = {
        name = self._name,
        game = self._game,
        system = self,
        is_active = function() return self._active end,
        close = function() self:close(owner) end,
        -- Send an event into the minigame if it exposes on_event
        send = function(event, payload)
          if self._game and self._game.on_event then self._game:on_event(event, payload) end
        end,
      }
    end
    return self._game
  end

  function sys:close(owner)
    if not self._active then return end
    if owner and owner ~= self._owner then return end
    self._active = false
    -- Clear relation on owner
    if self._owner and self._owner.minigame and self._owner.miniggame ~= nil then
      -- typo guard above; set correctly below
    end
    if self._owner and self._owner.minigame then
      self._owner.minigame = nil
    end
    self._name = nil
    self._owner = nil
    self._game = nil
    -- Reactivate input system when closing
    local input_sys = find_system(self.world, 'input')
    if input_sys then input_sys.active = true end
  end

  function sys:update(dt)
    if not self._active or not self._game then return end
    -- Hardcode a single key: Esc closes the minigame (edge-detected)
    local esc_down = love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown('escape') or false
    if esc_down and not self._esc_prev then
      self:close()
      self._esc_prev = esc_down
      return
    end
    self._esc_prev = esc_down
    if self._game.update then self._game:update(dt or 0) end
    if self._game.render then self._game:render() end
  end

  function sys:draw()
    if not self._active or not self._game then return end
    local lg = love and love.graphics
    if not lg then return end
    local W = (lg.getWidth and lg.getWidth()) or 800
    local H = (lg.getHeight and lg.getHeight()) or 600
    -- Dim background
    if lg.setColor and lg.rectangle then
      lg.setColor(self._bg)
      lg.rectangle('fill', 0, 0, W, H)
    end
    -- Center the game canvas
    local scale = self._scale or 2
    local cw, ch = (self._game.w or 200) * scale, (self._game.h or 140) * scale
    local cx, cy = (W - cw) / 2, (H - ch) / 2
    if self._game.draw then self._game:draw(lg, cx, cy, scale) end
    lg.setColor(1,1,1,1)
  end

  return sys
end
