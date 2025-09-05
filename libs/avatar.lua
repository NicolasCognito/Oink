local M = {}

local function is_candidate(e)
  return e and e.controllable and e.pos and e.vel
end

function M.candidates(world)
  local out, i = {}, 1
  if not world or not world.entities then return out end
  for idx = 1, #world.entities do
    local e = world.entities[idx]
    if is_candidate(e) then out[i] = e; i = i + 1 end
  end
  return out
end

function M.get(world)
  if not world or not world.entities then return nil end
  for i = 1, #world.entities do
    local e = world.entities[i]
    if is_candidate(e) and e.controlled == true then return e end
  end
  return nil
end

function M.set(world, entity)
  if not world or not world.entities then return nil end
  local target = nil
  for i = 1, #world.entities do
    local e = world.entities[i]
    if is_candidate(e) then
      if e == entity then
        e.controlled = true
        target = e
      else
        e.controlled = false
      end
    end
  end
  return target
end

function M.next(world, dir)
  dir = dir or 1
  local list = M.candidates(world)
  local n = #list
  if n == 0 then return nil end
  local cur = M.get(world)
  if not cur then
    return M.set(world, list[1])
  end
  local idx = 1
  for i = 1, n do if list[i] == cur then idx = i; break end end
  local step = (dir >= 0) and 1 or -1
  local next_idx = ((idx - 1 + step) % n) + 1
  return M.set(world, list[next_idx])
end

return M

