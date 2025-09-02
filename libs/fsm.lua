-- Minimal declarative FSM runner following ECS best practices:
-- - State machine is pure data stored on the entity (component)
-- - Systems execute the actions/conditions
-- - No component swapping; just switch current state name

local M = {}

-- Initialize a machine on an entity if missing
function M.ensure(entity, def)
  entity.fsm = entity.fsm or {
    def = def,
    current = def.initial or def.initial_state or 'idle',
    previous = nil,
    time = 0,
    data = {}, -- blackboard per-entity
  }
  return entity.fsm
end

-- Step the machine: run update, evaluate transitions, and change state if needed.
-- ctx is provided by the system (e.g., world, player ref, dt helpers)
function M.step(entity, ctx, dt)
  local fsm = entity.fsm
  if not fsm or not fsm.def then return end
  local states = fsm.def.states or {}
  local cur = states[fsm.current]
  if not cur then return end

  -- Execute update for current state (logic as data)
  if cur.update then cur.update(entity, ctx, dt, fsm) end

  -- Evaluate transitions in order; first true wins
  if cur.transitions then
    for i = 1, #cur.transitions do
      local tr = cur.transitions[i]
      if tr and tr.when and tr.to then
        if tr.when(entity, ctx, fsm) then
          -- Exit old state
          if cur.exit then cur.exit(entity, ctx, fsm) end
          fsm.previous = fsm.current
          fsm.current = tr.to
          fsm.time = 0
          -- Enter new state
          local nxt = states[fsm.current]
          if nxt and nxt.enter then nxt.enter(entity, ctx, fsm) end
          break
        end
      end
    end
  end

  fsm.time = (fsm.time or 0) + (dt or 0)
end

return M

