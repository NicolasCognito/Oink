local M = {}

local _queue = {}

function M.request(entity)
  if entity then _queue[#_queue+1] = entity end
end

function M.pending()
  return _queue
end

function M.drain()
  local out = _queue
  _queue = {}
  return out
end

return M

