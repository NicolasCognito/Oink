package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Input = require('systems.input')
local Composer = require('systems.composer')
local Context = require('systems.context_provider')
local Composer = require('systems.composer')
local Car = require('components.car')
local avatar = require('avatar')

describe('vehicle control handler', function()
  it('accelerates with W and turns with A/D', function()
    -- Stub keyboard
    local keys = {}
    _G.love = _G.love or {}
    love.keyboard = { isDown = function(k) return keys[k] == true end }

    local w = tiny.world(Context(), Composer(), Input())
    local car = Car.new({ x=0, y=0 })
    car.controllable = true
    w:add(car)
    w:update(0)
    avatar.set(w, car)

    -- Face right (heading=0), press W to accelerate
    car.heading = 0
    keys['w'] = true
    w:update(0.1)
    keys['w'] = false
    assert.is_true(car.vel.x > 0)
    assert.are.equal(0, math.floor(math.abs(car.vel.y)+0.5))

    -- Turn right with D
    local h0 = car.heading
    keys['d'] = true
    w:update(0.1)
    keys['d'] = false
    assert.is_true(car.heading > h0)
  end)
end)

