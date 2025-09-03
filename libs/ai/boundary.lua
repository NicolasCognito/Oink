-- Boundary checking utilities for AI navigation
local M = {}

-- Get screen dimensions (with fallback for testing)
function M.get_bounds()
  if love and love.graphics then
    return love.graphics.getWidth(), love.graphics.getHeight()
  end
  return 800, 600 -- Fallback for testing
end

-- Check if a point is within boundaries
function M.point_in_bounds(x, y, margin)
  local w, h = M.get_bounds()
  margin = margin or 0
  return x >= margin and x <= (w - margin) and y >= margin and y <= (h - margin)
end

-- Cast a ray from position in direction and check for boundary collision
-- Returns: hit (boolean), distance to boundary (number)
function M.raycast(pos, dir_x, dir_y, max_distance, margin)
  local w, h = M.get_bounds()
  margin = margin or 0
  max_distance = max_distance or 1000
  
  -- Normalize direction
  local len = math.sqrt(dir_x * dir_x + dir_y * dir_y)
  if len <= 0 then return false, 0 end
  dir_x, dir_y = dir_x / len, dir_y / len
  
  -- Calculate distances to each boundary
  local distances = {}
  
  -- Check horizontal boundaries
  if dir_x ~= 0 then
    -- Right boundary
    if dir_x > 0 then
      local dist = (w - margin - pos.x) / dir_x
      if dist > 0 then table.insert(distances, dist) end
    end
    -- Left boundary
    if dir_x < 0 then
      local dist = (margin - pos.x) / dir_x
      if dist > 0 then table.insert(distances, dist) end
    end
  end
  
  -- Check vertical boundaries
  if dir_y ~= 0 then
    -- Bottom boundary
    if dir_y > 0 then
      local dist = (h - margin - pos.y) / dir_y
      if dist > 0 then table.insert(distances, dist) end
    end
    -- Top boundary
    if dir_y < 0 then
      local dist = (margin - pos.y) / dir_y
      if dist > 0 then table.insert(distances, dist) end
    end
  end
  
  -- Find closest boundary hit
  local min_dist = max_distance
  for _, dist in ipairs(distances) do
    if dist < min_dist then
      min_dist = dist
    end
  end
  
  return min_dist < max_distance, min_dist
end

-- Find a safe random direction that avoids boundaries
function M.find_safe_direction(pos, radius, look_ahead, max_attempts)
  radius = radius or 6
  look_ahead = look_ahead or 30
  max_attempts = max_attempts or 12
  local margin = radius + 2
  
  -- Try random directions
  for i = 1, max_attempts do
    local angle = math.random() * math.pi * 2
    local dir_x = math.cos(angle)
    local dir_y = math.sin(angle)
    
    local hit, dist = M.raycast(pos, dir_x, dir_y, look_ahead, margin)
    if not hit or dist > look_ahead then
      return dir_x, dir_y, true
    end
  end
  
  -- If random fails, try systematic directions
  local angles = {0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, -3*math.pi/4, -math.pi/2, -math.pi/4}
  local best_dir = {0, 0}
  local best_dist = 0
  
  for _, angle in ipairs(angles) do
    local dir_x = math.cos(angle)
    local dir_y = math.sin(angle)
    local hit, dist = M.raycast(pos, dir_x, dir_y, look_ahead * 2, margin)
    
    if not hit or dist > best_dist then
      best_dist = hit and dist or look_ahead * 2
      best_dir = {dir_x, dir_y}
      if not hit then
        return dir_x, dir_y, true
      end
    end
  end
  
  -- Return best available direction (might still hit boundary eventually)
  return best_dir[1], best_dir[2], best_dist > radius * 2
end

-- Get direction away from nearest boundary
function M.direction_from_boundaries(pos, radius)
  local w, h = M.get_bounds()
  radius = radius or 6
  
  -- Calculate distances to all boundaries
  local dist_left = pos.x
  local dist_right = w - pos.x
  local dist_top = pos.y
  local dist_bottom = h - pos.y
  
  -- Find repulsion vector from boundaries
  local repel_x = 0
  local repel_y = 0
  local influence_dist = radius * 10
  
  if dist_left < influence_dist then
    repel_x = repel_x + (1 - dist_left / influence_dist)
  end
  if dist_right < influence_dist then
    repel_x = repel_x - (1 - dist_right / influence_dist)
  end
  if dist_top < influence_dist then
    repel_y = repel_y + (1 - dist_top / influence_dist)
  end
  if dist_bottom < influence_dist then
    repel_y = repel_y - (1 - dist_bottom / influence_dist)
  end
  
  -- Normalize
  local len = math.sqrt(repel_x * repel_x + repel_y * repel_y)
  if len > 0 then
    return repel_x / len, repel_y / len
  end
  
  -- If not near any boundary, return nil
  return nil, nil
end

-- Reflect a direction vector off boundaries if needed
function M.reflect_direction(pos, dir_x, dir_y, radius, look_ahead)
  radius = radius or 6
  look_ahead = look_ahead or 20
  local margin = radius + 2
  
  local hit, dist = M.raycast(pos, dir_x, dir_y, look_ahead, margin)
  if not hit then
    return dir_x, dir_y, false
  end
  
  -- Determine which boundary we're hitting
  local w, h = M.get_bounds()
  local future_x = pos.x + dir_x * dist
  local future_y = pos.y + dir_y * dist
  
  local new_dir_x, new_dir_y = dir_x, dir_y
  
  -- Reflect off vertical boundaries
  if future_x <= margin or future_x >= (w - margin) then
    new_dir_x = -dir_x
  end
  
  -- Reflect off horizontal boundaries
  if future_y <= margin or future_y >= (h - margin) then
    new_dir_y = -dir_y
  end
  
  return new_dir_x, new_dir_y, true
end

return M