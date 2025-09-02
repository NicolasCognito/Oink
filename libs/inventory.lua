local M = {}

-- Create a new inventory with a capacity cap
function M.new(cap)
  return { cap = cap or 10, items = {}, items_value = {}, count = 0, value = 0 }
end

function M.isFull(inv)
  return (inv.count or 0) >= (inv.cap or 0)
end

-- Add an item if there is capacity. Returns true on success.
function M.add(inv, name, value)
  if M.isFull(inv) then return false end
  inv.count = (inv.count or 0) + 1
  inv.value = (inv.value or 0) + (value or 0)
  inv.items[name] = (inv.items[name] or 0) + 1
  inv.items_value[name] = (inv.items_value[name] or 0) + (value or 0)
  return true
end

-- Transfer all items and total value from one inventory to another.
function M.transfer_all(from, to)
  if not (from and to) then return false end
  -- Move counts per item
  for name, count in pairs(from.items or {}) do
    if count and count > 0 then
      to.items[name] = (to.items[name] or 0) + count
      local v = (from.items_value and from.items_value[name]) or 0
      to.items_value = to.items_value or {}
      to.items_value[name] = (to.items_value[name] or 0) + v
      if from.items_value then from.items_value[name] = 0 end
    end
  end
  -- Move totals
  to.count = (to.count or 0) + (from.count or 0)
  to.value = (to.value or 0) + (from.value or 0)
  -- Clear source
  from.items = {}
  from.items_value = {}
  from.count = 0
  from.value = 0
  return true
end

-- Transfer with filters/limits.
-- opts:
--   names: array or set of item names to move (nil means all)
--   max_count: max number of items to move (nil means all)
function M.transfer(from, to, opts)
  if not (from and to) then return false end
  opts = opts or {}
  local names_set
  if opts.names then
    names_set = {}
    for _, n in ipairs(opts.names) do names_set[n] = true end
  end
  local remaining = opts.max_count or math.huge
  to.items = to.items or {}
  to.items_value = to.items_value or {}
  from.items = from.items or {}
  from.items_value = from.items_value or {}

  for name, count in pairs(from.items) do
    if remaining <= 0 then break end
    if (not names_set) or names_set[name] then
      local move = math.min(count or 0, remaining)
      if move > 0 then
        -- Determine per-item value for this name
        local total_val = from.items_value[name] or 0
        local per = (count > 0) and (total_val / count) or 0
        local moved_val = per * move
        -- Update destination
        to.items[name] = (to.items[name] or 0) + move
        to.items_value[name] = (to.items_value[name] or 0) + moved_val
        to.count = (to.count or 0) + move
        to.value = (to.value or 0) + moved_val
        -- Update source
        from.items[name] = count - move
        from.items_value[name] = math.max(0, total_val - moved_val)
        from.count = (from.count or 0) - move
        from.value = math.max(0, (from.value or 0) - moved_val)
        remaining = remaining - move
      end
    end
  end
  return true
end

return M
