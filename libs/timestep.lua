local M = {}

-- Probabilistic sub-stepping time scaler
-- Applies per-entity time scaling by running the provided process function
-- multiple times based on `entity.time_scale`.
--
-- Behavior:
--  - scale <= 0: no updates
--  - 0 < scale < 1: update with probability = scale (using full dt)
--  - scale >= 1: run floor(scale) updates, and an extra update with
--                probability = fractional part (each with full dt)
function M.scaled_process(entity, dt, process_fn)
  local scale = entity and entity.time_scale or 1.0

  if not process_fn or dt == nil then return end

  if scale <= 0 then return end

  if scale < 1 then
    if math.random() < scale then
      process_fn(entity, dt)
    end
    return
  end

  local whole = math.floor(scale)
  local frac = scale - whole

  for _ = 1, whole do
    process_fn(entity, dt)
  end

  if frac > 0 and math.random() < frac then
    process_fn(entity, dt)
  end
end

-- Optional helper for accumulator-style systems (unused currently)
function M.get_steps(scale, accumulated_error)
  accumulated_error = accumulated_error or 0
  scale = scale or 1.0
  if scale <= 0 then return 0, accumulated_error end
  local total = scale + accumulated_error
  local steps = math.floor(total)
  local new_err = total - steps
  return steps, new_err
end

return M

