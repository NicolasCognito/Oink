package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

_G.love = _G.love or {}
love.keyboard = love.keyboard or { isDown = function() return false end }

local tiny = require('tiny')
local Input = require('systems.input')
local avatar = require('avatar')

describe('zone input priority', function()
  it('routes keys to highest-priority overlapped zone', function()
    local keys = {}
    love.keyboard.isDown = function(k) return keys[k] == true end

    local w = tiny.world(Input())
    local player = { pos={x=10,y=10}, vel={x=0,y=0}, controllable=true }
    local got = {}
    local z1 = { zone=true, rect={x=0,y=0,w=40,h=40}, input_priority=1,
      on_input=function(self, input, ctx) if input.pressed('m') then got[#got+1] = 'z1:m' end end }
    local z2 = { zone=true, rect={x=0,y=0,w=40,h=40}, input_priority=2,
      on_input=function(self, input, ctx) if input.pressed('m') then got[#got+1] = 'z2:m' end end }
    w:add(player); w:add(z1); w:add(z2)
    w:update(0)
    avatar.set(w, player)

    -- press 'm' once -> should go to z2 (higher prio)
    keys['m'] = true
    w:update(0.016)
    keys['m'] = false
    w:update(0)

    assert.are.same({'z2:m'}, got)
  end)
end)
