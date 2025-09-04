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

-- Find the first free numeric index in a sparse array
local function first_free_index(t)
  local i = 1
  while t and t[i] ~= nil do
    i = i + 1
  end
  return i
end

-- Reserve a fixed slot index for a given name. The slot persists at index and
-- does not compress on empty; it keeps {count=0,value=0} when "empty".
function M.reserve_slot(inv, index, name, opts)
  if not inv or not index then return false end
  opts = opts or {}
  inv.slots = inv.slots or {}
  local s = inv.slots[index]
  if s then
    -- If it's an empty non-entity slot, adopt the reserved name
    if name and (s.count or 0) == 0 and not s.entity then s.name = name end
    s.permanent = true
  else
    inv.slots[index] = { name = name, value = 0, count = 0, permanent = true }
  end
  return true
end

local function add_slot(inv, name, value)
  -- stack into any existing slot with same name (search sparse array)
  for i, s in pairs(inv.slots or {}) do
    if s and s.name == name then
      s.count = (s.count or 1) + 1
      s.value = (s.value or 0) + (value or 0)
      return true -- stacked
    end
  end
  -- otherwise, create a new slot with count=1
  local idx = first_free_index(inv.slots)
  inv.slots[idx] = { name = name, value = value or 0, count = 1 }
  return false -- created
end

-- Add an item if there is a free slot. Returns true on success.
function M.add(inv, name, value)
  name = name or 'item'
  if M.isFull(inv) then return false end
  local stacked = add_slot(inv, name, value)
  -- Update summaries (track total item count and value)
  inv.count = (inv.count or 0) + 1
  inv.value = (inv.value or 0) + (value or 0)
  inv.items = inv.items or {}
  inv.items[name] = (inv.items[name] or 0) + 1
  inv.items_value = inv.items_value or {}
  inv.items_value[name] = (inv.items_value[name] or 0) + (value or 0)
  return true
end

-- Add a persistent entity into a dedicated slot (no stacking by slot, but summary increases)
function M.add_entity(inv, entity)
  if not inv or not entity then return false end
  if M.isFull(inv) then return false end
  local name = (entity.collectable and entity.collectable.name) or 'item'
  local value = (entity.collectable and entity.collectable.value) or 0
  -- push a dedicated slot with ref; do not merge slots
  local idx = first_free_index(inv.slots)
  inv.slots[idx] = { entity = entity, name = name, value = value, count = 1, persistent = true }
  inv.count = (inv.count or 0) + 1
  inv.value = (inv.value or 0) + (value or 0)
  inv.items[name] = (inv.items[name] or 0) + 1
  inv.items_value[name] = (inv.items_value[name] or 0) + (value or 0)
  return true
end

-- Remove one item from a given slot index. Returns { name, value } or nil.
function M.remove_one(inv, index)
  if not inv or not inv.slots then return nil end
  local s = inv.slots[index]
  if not s or (s.count or 0) <= 0 then return nil end
  if s.entity then
    -- Persistent entity: remove entire slot and return the entity
    local name = s.name
    local value = s.value or 0
    local ent = s.entity
    inv.items[name] = math.max(0, (inv.items[name] or 0) - 1)
    inv.items_value[name] = math.max(0, (inv.items_value[name] or 0) - value)
    inv.count = math.max(0, (inv.count or 0) - 1)
    inv.value = math.max(0, (inv.value or 0) - value)
    -- Do not compress slots; leave a hole to preserve indices
    inv.slots[index] = nil
    return { name = name, value = value, entity = ent, persistent = true }
  end
  local name = s.name
  local per = (s.count and s.count > 0) and ((s.value or 0) / s.count) or 0
  s.count = (s.count or 0) - 1
  s.value = math.max(0, (s.value or 0) - per)
  inv.items[name] = math.max(0, (inv.items[name] or 0) - 1)
  inv.items_value[name] = math.max(0, (inv.items_value[name] or 0) - per)
  inv.count = math.max(0, (inv.count or 0) - 1)
  inv.value = math.max(0, (inv.value or 0) - per)
  if (s.count or 0) <= 0 then
    if s.permanent then
      -- Keep the slot as a zero-count entry
      s.count = 0
      s.value = 0
    else
      -- Do not compress slots; leave a hole to preserve indices
      inv.slots[index] = nil
    end
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
    for _, s in pairs(from.slots or {}) do
      if s then
        local j = first_free_index(to.slots)
        to.slots[j] = { name = s.name, value = s.value }
      end
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
          for i, s in pairs(from.slots) do
            if removed >= move then break end
            if s and s.name == name then
              if to.slots then
                local j = first_free_index(to.slots)
                to.slots[j] = { name = name, value = per }
              end
              -- Do not compress source slots
              from.slots[i] = nil
              removed = removed + 1
            end
          end
        end
      end
    end
  end
  return true
end

return M
