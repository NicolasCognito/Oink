local avatar = require('avatar')

local layerOrder = {
  background = 0,
  zones = 100,
  world = 200,
  overlay = 800,
  ui = 1000,
}

local function gather_drawcalls(world)
  local calls = {}
  local function push(layer, order, fn)
    calls[#calls+1] = { layer = layer, order = order or 0, fn = fn }
  end
  for i = 1, #world.entities do
    local e = world.entities[i]
    if e then
      if e.draw_handlers then
        for j = 1, #e.draw_handlers do
          local h = e.draw_handlers[j]
          if h and h.draw then
            push(h.layer or 'world', h.order or 0, function() h.draw(e, love.graphics, { world = world }) end)
          end
        end
      end
    end
  end
  return calls
end

local function sort_calls(a, b)
  local la = layerOrder[a.layer] or 0
  local lb = layerOrder[b.layer] or 0
  if la ~= lb then return la < lb end
  if a.order ~= b.order then return a.order < b.order end
  return false
end

local M = {}

function M.draw(world)
  if not world or not world.entities then return end
  local calls = gather_drawcalls(world)
  table.sort(calls, sort_calls)
  for i = 1, #calls do calls[i].fn() end
end

return M
