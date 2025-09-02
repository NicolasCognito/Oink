local M = {}

-- Squared distance between two points
function M.dist2(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return dx*dx + dy*dy
end

-- Returns true if two circles overlap.
-- Accepts either numeric coords or tables with x,y fields.
function M.circles_overlap(a, ar, b, br)
  local ax, ay, bx, by
  if type(a) == 'table' then ax, ay = a.x, a.y else ax, ay = a, ar; ar = b; b, br = nil, nil end
  if type(b) == 'table' then bx, by = b.x, b.y else bx, by = bx, by end
  -- If called with tables: circles_overlap({x=..,y=..}, r1, {x=..,y=..}, r2)
  -- If called with numbers: circles_overlap(x1, y1, x2, y2, r1, r2)
  if bx == nil and type(ar) == 'number' then
    -- numeric form: a=ax, ar=ay, b=bx=x2, br=by=y2, extra args r1,r2 passed via select
    -- Normalize into table form by parsing varargs
    error('circles_overlap: invalid arguments')
  end
  local r1, r2
  if type(a) == 'table' then
    r1 = ar
  else
    -- numeric signature not supported by this branch
    error('circles_overlap: use tables with x,y and radii')
  end
  if type(b) == 'table' then
    r2 = br
  else
    error('circles_overlap: use tables with x,y and radii')
  end
  local rsum = (r1 or 0) + (r2 or 0)
  return M.dist2(ax, ay, bx, by) <= (rsum * rsum)
end

return M

