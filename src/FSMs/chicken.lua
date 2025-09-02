local move = require('ai.movement')
local spawn = require('spawn')
local Egg = require('components.egg')

local function random_dir()
  local a = math.random() * math.pi * 2
  return math.cos(a), math.sin(a)
end

return {
  initial = 'wander',
  states = {
    wander = {
      enter = function(e)
        e._wander_timer = 0
        e._wander_change = (e.wander_change or 1.5) * (0.5 + math.random())
        e._dirx, e._diry = random_dir()
        e._egg_timer = e._egg_timer or 0
      end,
      update = function(e, ctx, dt)
        -- change direction periodically
        e._wander_timer = (e._wander_timer or 0) + (dt or 0)
        if e._wander_timer >= (e._wander_change or 1.5) then
          e._wander_timer = 0
          e._wander_change = (e.wander_change or 1.5) * (0.5 + math.random())
          e._dirx, e._diry = random_dir()
        end
        local speed = e.speed or 60
        e.vel.x = (e._dirx or 0) * speed
        e.vel.y = (e._diry or 0) * speed

        -- lay eggs periodically
        local interval = e.egg_interval or 5
        e._egg_timer = (e._egg_timer or 0) + (dt or 0)
        if e._egg_timer >= interval then
          e._egg_timer = e._egg_timer - interval
          local x = e.pos.x + (math.random()*2-1) * 4
          local y = e.pos.y + (math.random()*2-1) * 4
          spawn.request(Egg.new(x, y, { ttl = e.egg_ttl or 15 }))
        end
      end,
    },
  }
}

