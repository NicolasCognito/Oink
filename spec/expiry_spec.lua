package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Expiry = require('systems.expiry')
local Destroyer = require('systems.destroyer')

describe('expiry system', function()
  it('expires entity after ttl', function()
    local w = tiny.world(Expiry(), Destroyer())
    local e = { pos={x=0,y=0}, expire_ttl = 0.1, expire_age = 0 }
    w:add(e)
    w:update(0.05)
    assert.is_true(e.expire_age > 0)
    -- not yet expired
    w:update(0.05)
    -- run one extra tick to process removals queued by Destroyer
    w:update(0)
    -- tiny keeps entities array compact; check it's no longer present
    for _, ent in ipairs(w.entities) do
      assert.is_true(ent ~= e)
    end
  end)

  it('does not advance when time_scale = 0', function()
    local w = tiny.world(Expiry(), Destroyer())
    local e = { expire_ttl = 0.2, expire_age = 0, time_scale = 0 }
    w:add(e)
    for _=1,10 do w:update(0.05) end -- lots of time
    -- should not be removed
    local found = false
    for _, ent in ipairs(w.entities) do if ent == e then found = true end end
    assert.is_true(found)
    assert.are.equal(0, e.expire_age or 0)
  end)

  it('expires faster with integer time_scale > 1 deterministically', function()
    local w = tiny.world(Expiry(), Destroyer())
    local e = { expire_ttl = 0.1, expire_age = 0, time_scale = 2.0 }
    w:add(e)
    -- One update of 0.05 with scale=2 should apply two steps of 0.05 each
    w:update(0.05)
    -- process removal
    w:update(0)
    -- should be removed
    for _, ent in ipairs(w.entities) do
      assert.is_true(ent ~= e)
    end
  end)
end)
