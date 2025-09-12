local move = require('ai.movement')
local spawn = require('spawn')
local Egg = require('components.egg')
local boundary = require('ai.boundary')

-- Get a safe random direction that won't hit walls
local function get_safe_direction(e, look_ahead)
  look_ahead = look_ahead or 30
  local dirx, diry, safe = boundary.find_safe_direction(e.pos, e.radius, look_ahead)
  
  if safe then
    return dirx, diry
  end
  
  -- If no safe direction found, try to move away from boundaries
  local away_x, away_y = boundary.direction_from_boundaries(e.pos, e.radius)
  if away_x and away_y then
    return away_x, away_y
  end
  
  -- Last resort: stay still
  return 0, 0
end

-- Check if current direction is still valid
local function should_change_direction(e, look_ahead)
  look_ahead = look_ahead or 20
  
  -- Check current direction
  if e._dirx and e._diry then
    local hit, dist = boundary.raycast(e.pos, e._dirx, e._diry, look_ahead, e.radius + 2)
    return hit and dist < look_ahead
  end
  
  return true -- No direction set, should pick one
end

return {
  initial = 'wander',
  states = {
    wander = {
      enter = function(e)
        e._wander_timer = 0
        e._wander_change = (e.wander_change or 1.5) * (0.5 + math.random())
        -- Get initial safe direction
        e._dirx, e._diry = get_safe_direction(e, 40)
        e._egg_timer = e._egg_timer or 0
        e._boundary_check_timer = 0
      end,
      update = function(e, ctx, dt)
        -- Check for boundary collision more frequently
        e._boundary_check_timer = (e._boundary_check_timer or 0) + (dt or 0)
        
        -- Check if we need to change direction due to approaching boundary
        if e._boundary_check_timer >= 0.1 then -- Check every 100ms
          e._boundary_check_timer = 0
          
          if should_change_direction(e, 30) then
            -- Pick a new safe direction immediately
            e._dirx, e._diry = get_safe_direction(e, 40)
            e._wander_timer = 0 -- Reset wander timer
            e._wander_change = (e.wander_change or 1.5) * (0.5 + math.random())
          end
        end
        
        -- Regular periodic direction change (when not forced by boundaries)
        e._wander_timer = (e._wander_timer or 0) + (dt or 0)
        if e._wander_timer >= (e._wander_change or 1.5) then
          e._wander_timer = 0
          e._wander_change = (e.wander_change or 1.5) * (0.5 + math.random())
          -- Only change direction if current one is still valid
          if not should_change_direction(e, 50) then
            -- Current direction is fine, maybe change anyway for variety (50% chance)
            if math.random() > 0.5 then
              e._dirx, e._diry = get_safe_direction(e, 40)
            end
          else
            -- Must change direction
            e._dirx, e._diry = get_safe_direction(e, 40)
          end
        end
        
        -- Apply velocity
        local speed = e.speed or 60
        e.vel.x = (e._dirx or 0) * speed
        e.vel.y = (e._diry or 0) * speed

        -- Egg laying logic (unchanged)
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