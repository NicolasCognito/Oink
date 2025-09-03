-- Simple helper to host multiple child FSMs per entity, without changing libs/fsm.lua

local M = {}

local function ensure_table(e)
  e.fsm_multi = e.fsm_multi or {}
  return e.fsm_multi
end

function M.ensure(entity, key, def, opts)
  local bag = ensure_table(entity)
  opts = opts or {}
  local m = bag[key]
  if not m or opts.reset then
    bag[key] = {
      def = def,
      current = (def and (def.initial or def.initial_state)) or 'idle',
      previous = nil,
      time = 0,
      data = {},
    }
    m = bag[key]
    -- run enter of initial state if present
    local states = def and def.states or {}
    local s = states[m.current]
    if s and s.enter then s.enter(entity, nil, m) end
  end
  return m
end

function M.reset(entity, key, new_def)
  local bag = ensure_table(entity)
  if new_def then
    bag[key] = nil
    return M.ensure(entity, key, new_def, { reset = true })
  end
  local m = bag[key]
  if m and m.def then
    bag[key] = nil
    return M.ensure(entity, key, m.def, { reset = true })
  end
end

function M.get(entity, key)
  local bag = entity and entity.fsm_multi
  return bag and bag[key]
end

function M.in_state(entity, key, name)
  local m = M.get(entity, key)
  return m and m.current == name
end

-- One tick for a child FSM
function M.step(entity, key, ctx, dt)
  local m = M.get(entity, key)
  if not (m and m.def) then return nil end
  local states = m.def.states or {}
  local cur = states[m.current]
  if not cur then return m.current end

  if cur.update then cur.update(entity, ctx, dt, m) end
  if cur.transitions then
    for i = 1, #cur.transitions do
      local tr = cur.transitions[i]
      if tr and tr.when and tr.to then
        if tr.when(entity, ctx, m) then
          if cur.exit then cur.exit(entity, ctx, m) end
          m.previous = m.current
          m.current = tr.to
          m.time = 0
          local nxt = states[m.current]
          if nxt and nxt.enter then nxt.enter(entity, ctx, m) end
          break
        end
      end
    end
  end
  m.time = (m.time or 0) + (dt or 0)
  return m.current
end

return M

