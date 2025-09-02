package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
}, ';')

local move = require('ai.movement')

describe('ai.movement helpers', function()
  it('computes normalized direction', function()
    local a = {x=0,y=0}; local b = {x=3,y=4}
    local nx, ny = move.direction(a,b)
    assert.are.equal(0.6, nx)
    assert.are.equal(0.8, ny)
  end)
  it('seek returns velocity scaled by speed', function()
    local a = {x=0,y=0}; local b = {x=0,y=10}
    local vx, vy = move.seek(a,b,5)
    assert.are.equal(0, vx)
    assert.are.equal(5, vy)
  end)
  it('within checks radius using squared distance', function()
    local a = {x=0,y=0}; local b = {x=3,y=4}
    assert.is_true(move.within(a,b,5))
    assert.is_false(move.within(a,b,4.9))
  end)
end)

