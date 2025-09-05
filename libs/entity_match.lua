local M = {}

local function is_function(x) return type(x) == 'function' end
local function is_table(x) return type(x) == 'table' end
local function is_array(t)
  if not is_table(t) then return false end
  return t[1] ~= nil and next(t, #t) ~= nil or t[1] ~= nil
end

local function truthy(v) return not not v end

local function all_components(item, list)
  if not list then return true end
  for i = 1, #list do
    local key = list[i]
    if not truthy(item and item[key]) then return false end
  end
  return true
end

local function any_components(item, list)
  if not list or #list == 0 then return true end
  for i = 1, #list do
    local key = list[i]
    if truthy(item and item[key]) then return true end
  end
  return false
end

local function none_components(item, list)
  if not list then return true end
  for i = 1, #list do
    local key = list[i]
    if truthy(item and item[key]) then return false end
  end
  return true
end

local function normalize_where(where)
  if not where then return nil end
  if is_function(where) then return { where } end
  if is_table(where) and is_array(where) then return where end
  return nil
end

local function entry_matches(collector, item, ctx, entry)
  if is_function(entry) then
    return entry(collector, item, ctx) == true
  elseif is_table(entry) then
    -- Structured entry: { all_of, any_of, none_of, where }
    if not all_components(item, entry.all_of or {}) then return false end
    if not any_components(item, entry.any_of or {}) then return false end
    if not none_components(item, entry.none_of or {}) then return false end
    local ws = normalize_where(entry.where)
    if ws then
      for i = 1, #ws do
        if ws[i](collector, item, ctx) ~= true then return false end
      end
    end
    return true
  end
  return false
end

local function normalize_list(list)
  if list == nil then return {} end
  if is_function(list) then return { list } end
  if is_table(list) then
    -- If it's an array of entries, keep; else treat as single entry
    if list[1] ~= nil then return list end
    return { list }
  end
  return {}
end

function M.match_policy(collector, item, ctx, policy)
  if not policy then policy = {} end
  if not item or item == collector then return false end
  local blacklist = normalize_list(policy.blacklist)
  local whitelist = normalize_list(policy.whitelist)

  -- Blacklist wins
  for i = 1, #blacklist do
    if entry_matches(collector, item, ctx, blacklist[i]) then return false end
  end

  -- Whitelist default: accept when empty
  if #whitelist == 0 then return true end
  for i = 1, #whitelist do
    if entry_matches(collector, item, ctx, whitelist[i]) then return true end
  end
  return false
end

function M.build_query(policy)
  return function(collector, ctx)
    local items = ctx and ctx.collectables or {}
    local out, oi = {}, 1
    for i = 1, #items do
      local it = items[i]
      if it and M.match_policy(collector, it, ctx, policy) then
        out[oi] = it; oi = oi + 1
      end
    end
    return out
  end
end

return M

