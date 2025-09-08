package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Input = require('systems.input')
local Inventory = require('inventory')
local avatar = require('avatar')

describe('input_inventory targets controlled avatar', function()
  it('selects slots on the controlled entity after switching', function()
    -- Stub keyboard
    local keys = {}
    _G.love = _G.love or {}
    love.keyboard = { isDown = function(k) return keys[k] == true end }

    local w = tiny.world(Input())
    local a = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, inventory=Inventory.new(5) }
    local b = { pos={x=0,y=0}, vel={x=0,y=0}, controllable=true, inventory=Inventory.new(5) }
    w:add(a); w:add(b)
    w:update(0)

    -- Start controlling a, then switch to b
    avatar.set(w, a)
    avatar.set(w, b)

    -- Press '2' to select slot 2 on controlled (b)
    keys['2'] = true
    w:update(0.016)
    keys['2'] = false
    w:update(0.016)

    assert.are.equal(2, b.inventory.active_index)
    assert.are_not.equal(2, a.inventory.active_index)
  end)
end)
