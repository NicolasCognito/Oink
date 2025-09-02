local M = {}

-- Returns normalized direction from a to b. If zero-length, returns 0,0.
function M.direction(a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local len = math.sqrt(dx*dx + dy*dy)
  if len > 0 then return dx/len, dy/len else return 0, 0 end
end

-- Seek: produce a velocity toward target at given speed.
function M.seek(a, b, speed)
  local nx, ny = M.direction(a, b)
  return nx * (speed or 0), ny * (speed or 0)
end

-- Distance squared between points a and b.
function M.dist2(a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  return dx*dx + dy*dy
end

-- Within radius check using squared distance.
function M.within(a, b, r)
  local rr = (r or 0)
  return M.dist2(a, b) <= rr*rr
end

return M

