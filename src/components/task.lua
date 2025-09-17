-- Holds current task and optional queue
local M = {}

function M.new(current)
  return { task = { current = current or nil, queue = {} } }
end

return M

