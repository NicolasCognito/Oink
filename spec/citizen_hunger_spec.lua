package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local Zones = require('systems.zones')
local Agents = require('systems.agents')
local Move = require('systems.move')
local Collect = require('systems.collect')
local Spawner = require('systems.spawner')
local Citizen = require('components.citizen')
local Egg = require('components.egg')

describe('citizen hunger behavior', function()
  it('becomes hungry, collects an egg (food), and resumes working', function()
    local w = tiny.world(Zones(), Agents(), Move(), Collect(), Spawner())
    -- citizen with fast hunger so test is quick; not a collector by default
    local c = Citizen.new({ x = 0, y = 0, speed = 60,
      hunger_rate_work = 5.0, hunger_rate_rest = 0.0, hunger_max = 1.0, hunger_min = 0.2,
      work_def = { initial = 'idle', states = { idle = { update=function(e) e.vel.x,e.vel.y=0,0 end } } }
    })
    w:add(c)
    -- Place an egg nearby
    local e = Egg.new(10, 0, { ttl = 999 })
    w:add(e)
    -- Run updates to trigger hunger and collection; stop once satiated
    local satiated = false
    for _=1,40 do
      w:update(0.1)
      if (c.hunger or 0) <= (c.hunger_min or 0.2) then satiated = true; break end
    end
    assert.is_true(satiated)
  end)
end)
