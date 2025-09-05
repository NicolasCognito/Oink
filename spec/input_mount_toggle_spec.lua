package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')
local InputMount = require('systems.input_mount')

describe('input_mount toggles driver collectable on Enter', function()
  it('sets and clears player.collectable', function()
    -- Stub keyboard
    local keys = {}
    _G.love = _G.love or {}
    love.keyboard = { isDown = function(k) return keys[k] == true end }

    local w = tiny.world(InputMount())
    local p = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true }
    w:add(p)
    w:update(0)
    avatar.set(w, p)

    -- Press Enter to set collectable
    keys['return'] = true
    w:update(0.016)
    keys['return'] = false
    w:update(0.016)
    assert.is_truthy(p.collectable)
    assert.are.equal('driver', p.collectable.name)
    assert.is_true(p.collectable.persistent)

    -- Wait for debounce, then press Enter again to clear
    w:update(0.3)
    keys['return'] = true
    w:update(0.016)
    keys['return'] = false
    w:update(0.016)
    assert.is_nil(p.collectable)
  end)
end)
