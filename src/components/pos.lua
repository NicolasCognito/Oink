local M = {}

function M.new(x, y)
  return { pos = { x = x or 0, y = y or 0 } }
end

return M

