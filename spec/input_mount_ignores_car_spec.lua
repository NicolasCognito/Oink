package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')
local Input = require('systems.input')
local Car = require('components.car')

describe('input_mount ignores non-player (car) for Enter toggle', function()
  it('does not set collectable on car when pressing Enter', function()
    -- Stub keyboard
    local keys = {}
    _G.love = _G.love or {}
    love.keyboard = { isDown = function(k) return keys[k] == true end }

    local w = tiny.world(Input())
    local car = Car.new({ x = 0, y = 0 })
    car.controllable = true
    w:add(car)
    w:update(0)
    avatar.set(w, car)

    keys['return'] = true
    w:update(0.016)
    keys['return'] = false
    w:update(0.016)

    assert.is_nil(car.collectable)
  end)
end)
