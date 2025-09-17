local M = {}

function M.compose(...)
  local e = {}
  for i = 1, select('#', ...) do
    local c = select(i, ...)
    if c then
      for k, v in pairs(c) do e[k] = v end
    end
  end
  return e
end

return M

