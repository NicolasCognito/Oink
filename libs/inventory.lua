local M = {}

-- Create a new inventory with a capacity cap
function M.new(cap)
  return { cap = cap or 10, items = {}, count = 0, value = 0 }
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
  return true
end

return M

