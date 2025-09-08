package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

-- Minimal love stub for keyboard
_G.love = _G.love or {}
love.keyboard = love.keyboard or { isDown = function() return false end }

local tiny = require('tiny')
local Input = require('systems.input')
local Composer = require('systems.composer')
local Zones = require('systems.zones')
local Player = require('components.player')
local Empty = require('Zones.empty_area')

local function has_zone_type(world, typ)
  for _, e in ipairs(world.entities) do
    if e and e.zone and e.type == typ then return true end
  end
  return false
end

describe('empty area zone transform controls', function()
  it('transforms to a Mine when pressing M', function()
    local Context = require('systems.context_provider')
    local w = tiny.world(Context(), Composer(), Input(), Zones())
    local p = Player.new({ x=10, y=10 })
    local z = Empty.new(0,0,40,40)
    w:add(p); w:add(z)
    w:update(0)
    local avatar = require('avatar')
    avatar.set(w, p)
    -- Press M for one frame
    love.keyboard.isDown = function(key) return key == 'm' end
    w:update(0.016)
    -- Release keys and flush add/remove
    love.keyboard.isDown = function() return false end
    w:update(0)
    assert.is_true(has_zone_type(w, 'mine'))
  end)

  it('transforms to a Time Vortex when pressing T', function()
    local Context = require('systems.context_provider')
    local w = tiny.world(Context(), Composer(), Input(), Zones())
    local p = Player.new({ x=10, y=10 })
    local z = Empty.new(0,0,40,40)
    w:add(p); w:add(z)
    w:update(0)
    local avatar = require('avatar')
    avatar.set(w, p)
    love.keyboard.isDown = function(key) return key == 't' end
    w:update(0.016)
    love.keyboard.isDown = function() return false end
    w:update(0)
    assert.is_true(has_zone_type(w, 'time_vortex'))
  end)

  it('transforms to a Vault when pressing V', function()
    local Context = require('systems.context_provider')
    local w = tiny.world(Context(), Composer(), Input(), Zones())
    local p = Player.new({ x=10, y=10 })
    local z = Empty.new(0,0,40,40)
    w:add(p); w:add(z)
    w:update(0)
    local avatar = require('avatar')
    avatar.set(w, p)
    love.keyboard.isDown = function(key) return key == 'v' end
    w:update(0.016)
    love.keyboard.isDown = function() return false end
    w:update(0)
    assert.is_true(has_zone_type(w, 'vault'))
  end)
end)
