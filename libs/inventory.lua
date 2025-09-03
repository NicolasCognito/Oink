local M = {}

-- Create a new slot-based inventory; cap = number of slots (default 9)
function M.new(cap)
  return {
    cap = cap or 9,
    slots = {},        -- array of { name, value }
    items = {},        -- summary map: name -> count
    items_value = {},  -- summary map: name -> total value
    count = 0,         -- used slots
    value = 0,         -- total value
  }
end

function M.isFull(inv)
  local c = inv.count or 0
  local cap = inv.cap or 0
  return c >= cap
end

local function add_slot(inv, name, value)
  -- stack into existing slot if same name
  for i = 1, #(inv.slots or {}) do
    local s = inv.slots[i]
    if s and s.name == name then
      s.count = (s.count or 1) + 1
      s.value = (s.value or 0) + (value or 0)
      -- summaries updated by caller below
      return
    end
  end
  -- otherwise, create a new slot with count=1
  inv.slots[#inv.slots+1] = { name = name, value = value or 0, count = 1 }
  inv.count = (inv.count or 0) + 1
  inv.value = (inv.value or 0) + (value or 0)
  inv.items[name] = (inv.items[name] or 0) + 1
  inv.items_value[name] = (inv.items_value[name] or 0) + (value or 0)
end

-- Add an item if there is a free slot. Returns true on success.
function M.add(inv, name, value)
  name = name or 'item'
  if M.isFull(inv) then return false end
  add_slot(inv, name, value)
  return true
end

-- Remove one item from a given slot index. Returns { name, value } or nil.
function M.remove_one(inv, index)
  if not inv or not inv.slots then return nil end
  local s = inv.slots[index]
  if not s or (s.count or 0) <= 0 then return nil end
  local name = s.name
  local per = (s.count and s.count > 0) and ((s.value or 0) / s.count) or 0
  s.count = (s.count or 0) - 1
  s.value = math.max(0, (s.value or 0) - per)
  inv.items[name] = math.max(0, (inv.items[name] or 0) - 1)
  inv.items_value[name] = math.max(0, (inv.items_value[name] or 0) - per)
  inv.count = math.max(0, (inv.count or 0) - 1)
  inv.value = math.max(0, (inv.value or 0) - per)
  if (s.count or 0) <= 0 then
    table.remove(inv.slots, index)
  end
  return { name = name, value = per }
end

-- Transfer all items and total value from one inventory to another.
function M.transfer_all(from, to)
  if not (from and to) then return false end
  -- Move summaries
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
  -- Move slots if destination supports them
  if to.slots then
    for i = 1, #(from.slots or {}) do
      local s = from.slots[i]
      to.slots[#to.slots+1] = { name = s.name, value = s.value }
    end
  end
  -- Clear source
  from.slots = {}
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
        -- Update destination summaries
        to.items[name] = (to.items[name] or 0) + move
        to.items_value[name] = (to.items_value[name] or 0) + moved_val
        to.count = (to.count or 0) + move
        to.value = (to.value or 0) + moved_val
        -- Update source summaries
        from.items[name] = count - move
        from.items_value[name] = math.max(0, total_val - moved_val)
        from.count = (from.count or 0) - move
        from.value = math.max(0, (from.value or 0) - moved_val)
        remaining = remaining - move
        -- Remove slots from source; add to destination if it supports slots
        if from.slots then
          local removed = 0
          local i = 1
          while i <= #from.slots and removed < move do
            local s = from.slots[i]
            if s and s.name == name then
              if to.slots then
                to.slots[#to.slots+1] = { name = name, value = per }
              end
              table.remove(from.slots, i)
              removed = removed + 1
            else
              i = i + 1
            end
          end
        end
      end
    end
  end
  return true
end

return M
