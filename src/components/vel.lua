local M = {}

function M.new(vx, vy)
  return { vel = { x = vx or 0, y = vy or 0 } }
end

return M

