package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Input = require('systems.input')
local Context = require('systems.context_provider')
local avatar = require('avatar')
local H_character = require('input.handlers.character')

describe('input routes movement to controlled avatar', function()
  it('moves only the controlled entity; Tab switches', function()
    -- Stub keyboard
    local keys = {}
    _G.love = _G.love or {}
    love.keyboard = { isDown = function(k) return keys[k] == true end }

    local input = Input()
    local w = tiny.world(Context(), input)
    local e1 = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, speed=100, input_handlers = { H_character({}) } }
    local e2 = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, speed=100, input_handlers = { H_character({}) } }
    w:add(e1); w:add(e2)
    w:update(0)
    -- Select e1
    avatar.set(w, e1)
    -- Press D (right)
    keys['d'] = true
    w:update(0.016)
    keys['d'] = false
    assert.is_true(e1.vel.x > 0)
    assert.are.equal(0, e2.vel.x)

    -- Press Tab to switch
    keys['tab'] = true
    w:update(0.016)
    keys['tab'] = false
    -- Press A (left)
    keys['a'] = true
    w:update(0.016)
    keys['a'] = false
    assert.is_true(e2.vel.x < 0)
  end)
end)
