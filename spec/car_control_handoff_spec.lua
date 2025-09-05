package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')
local CarControl = require('systems.car_control')
local Car = require('components.car')

describe('car control handoff', function()
  it('switches to car when driver present, back to driver when removed', function()
    local w = tiny.world(CarControl())
    local car = Car.new({ x = 0, y = 0 })
    local driver = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, driver=true }
    w:add(car); w:add(driver)
    w:update(0)
    avatar.set(w, driver)

    -- Mount: place driver into car slot 1
    car.inventory.slots[1].entity = driver
    car.inventory.slots[1].count = 1
    w:update(0.016)
    assert.is_true(car.controllable)
    assert.is_false(driver.controllable)
    assert.are.equal(car, avatar.get(w))

    -- Unmount: clear slot 1
    car.inventory.slots[1].entity = nil
    car.inventory.slots[1].count = 0
    w:update(0.016)
    assert.is_false(car.controllable == true)
    assert.is_true(driver.controllable)
    assert.are.equal(driver, avatar.get(w))
  end)
end)

