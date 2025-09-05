package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local avatar = require('avatar')

describe('avatar control', function()
  it('sets, gets, and cycles exactly one controlled entity', function()
    local w = tiny.world()
    local a = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, label='A' }
    local b = { pos={x=1,y=0}, vel={x=0,y=0}, controllable=true, label='B' }
    w:add(a); w:add(b)
    w:update(0) -- apply additions

    -- No controller initially
    assert.is_nil(avatar.get(w))
    -- Set A
    avatar.set(w, a)
    assert.is_true(a.controlled == true)
    assert.is_true(b.controlled ~= true)
    assert.are.equal(a, avatar.get(w))
    -- Next cycles to B
    avatar.next(w, 1)
    assert.is_true(b.controlled == true)
    assert.is_true(a.controlled ~= true)
    assert.are.equal(b, avatar.get(w))
    -- Prev cycles back to A
    avatar.next(w, -1)
    assert.is_true(a.controlled == true)
  end)
end)
