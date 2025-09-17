local M = {}

function M.new(value)
  return { coin = { value = value or 1 } }
end

return M

