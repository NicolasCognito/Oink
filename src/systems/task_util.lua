local M = {}

local function is_array(t)
  if type(t) ~= 'table' then return false end
  local n = 0
  for k, _ in pairs(t) do
    if type(k) ~= 'number' then return false end
    n = n + 1
  end
  return n > 0
end

local function split_path(s)
  local parts = {}
  for seg in tostring(s):gmatch("[^%.]+") do parts[#parts+1] = seg end
  return parts
end

local function root_for(name, owner, task, world)
  if name == 'owner' then return owner end
  if name == 'task' then return task end
  if name == 'world' then return world end
  return nil
end

function M.read_path(owner, task, world, path)
  if not path then return nil end
  local parts
  if type(path) == 'string' then
    parts = split_path(path)
  elseif is_array(path) then
    parts = path
  else
    return nil
  end
  if #parts == 0 then return nil end
  local root = root_for(parts[1], owner, task, world)
  local i = 1
  if root then i = 2 else root = owner end
  local cur = root
  while cur and i <= #parts do
    cur = cur[parts[i]]
    i = i + 1
  end
  return cur
end

local function write_path(owner, task, world, path, value)
  if not path then return end
  local parts
  if type(path) == 'string' then parts = split_path(path) elseif is_array(path) then parts = path else return end
  if #parts == 0 then return end
  local root = root_for(parts[1], owner, task, world)
  local i = 1
  if root then i = 2 else root = owner end
  local cur = root
  while i < #parts do
    local k = parts[i]
    cur[k] = cur[k] or {}
    cur = cur[k]
    i = i + 1
  end
  cur[parts[#parts]] = value
end

local function looks_path_string(v)
  return type(v) == 'string' and (v:find('%.') or v == 'owner' or v == 'task' or v == 'world')
end

local function resolve_one(task, owner, world, key, spec)
  local v = task[key]
  -- Descriptor table
  if type(v) == 'table' and (v.eval or v.from or v.path or v.default) then
    if type(v.eval) == 'function' then
      local ok, res = pcall(v.eval, owner, task, world)
      if ok then return res end
    end
    local root = v.from and root_for(v.from, owner, task, world)
    if v.path then
      local p = v.path
      if v.from and type(p) == 'string' then p = split_path(p); table.insert(p, 1, v.from) end
      local res = M.read_path(owner, task, world, p)
      if res ~= nil then return res end
    end
    if v.default ~= nil then return v.default end
  end
  -- Function
  if type(v) == 'function' then
    local ok, res = pcall(v, owner, task, world)
    if ok then return res end
  end
  -- Path
  if looks_path_string(v) or is_array(v) then
    local res = M.read_path(owner, task, world, v)
    if res ~= nil then return res end
  end
  -- Literal
  if v ~= nil then return v end
  -- Fallbacks
  if spec and spec.fallback_paths then
    for i = 1, #spec.fallback_paths do
      local res = M.read_path(owner, task, world, spec.fallback_paths[i])
      if res ~= nil then return res end
    end
  end
  if spec and spec.default ~= nil then return spec.default end
  return nil
end

function M.resolve(task, owner, world, spec)
  local out = {}
  for key, pspec in pairs(spec) do
    out[key] = resolve_one(task, owner, world, key, pspec)
  end
  return out
end

function M.set_path(owner, task, world, path, value)
  -- allow plain field names to mean owner.<field>
  if type(path) == 'string' and not path:find('%.') and path ~= 'owner' and path ~= 'task' and path ~= 'world' then
    path = 'owner.' .. path
  end
  return write_path(owner, task, world, path, value)
end

return M

