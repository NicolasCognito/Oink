local M = {}

local _current = nil

function M.set(ctx)
  _current = ctx
end

-- If a snapshot is set, return it. Otherwise, build a minimal snapshot from world.
function M.get(world, dt)
  assert(_current ~= nil, 'ctx.get() called without an active snapshot; ensure Context system runs first')
  return _current
end

return M
