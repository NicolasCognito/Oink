local M = {}

local _current = nil

function M.set(ctx)
  _current = ctx
end

-- If a snapshot is set, return it. Otherwise, build a minimal snapshot from world.
function M.get(world, dt)
  if _current then return _current end
  if not world then return nil end
  local entities = world.entities
  local snapshot = { world = world, dt = dt, _cache = {} }
  local agents, collectables, zones, coins = {}, {}, {}, {}
  local ai, ci, zi, ko = 1, 1, 1, 1
  for i = 1, #entities do
    local e = entities[i]
    if e and not e.marked_for_destruction then
      if e.agent and e.pos then agents[ai] = e; ai = ai + 1 end
      if e.collectable then collectables[ci] = e; ci = ci + 1 end
      if e.zone then zones[zi] = e; zi = zi + 1 end
      if e.coin and e.pos then coins[ko] = e; ko = ko + 1 end
      if e.player then
        snapshot.players = snapshot.players or {}
        snapshot.players[#snapshot.players+1] = e
      end
    end
  end
  -- Include active avatar if available
  local ok, avatar = pcall(require, 'avatar')
  if ok and avatar and avatar.get then
    snapshot.active_avatar = avatar.get(world)
  end
  snapshot.player = snapshot.active_avatar or (snapshot.players and snapshot.players[1])
  snapshot.agents = agents
  snapshot.collectables = collectables
  snapshot.zones = zones
  snapshot.coins = coins
  function snapshot.query(name, predicate)
    if snapshot._cache[name] then return snapshot._cache[name] end
    local list = {}
    local li = 1
    if name == 'agents' then list = agents
    elseif name == 'collectables' then list = collectables
    elseif name == 'zones' then list = zones
    elseif name == 'coins' then list = coins
    else
      local pred = predicate
      if type(pred) ~= 'function' then pred = function(e) return e and e[name] end end
      for j = 1, #entities do
        local ej = entities[j]
        if ej and not ej.marked_for_destruction and pred(ej) then list[li] = ej; li = li + 1 end
      end
    end
    snapshot._cache[name] = list
    return list
  end
  return snapshot
end

return M
