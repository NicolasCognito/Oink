package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')
local ctx = require('ctx')
local avatar_ok, avatar = pcall(require, 'avatar')

return function()
  local sys = tiny.system()

  function sys:preProcess(dt)
    local world = self.world
    local entities = world.entities
    local snapshot = { world = world, dt = dt, _cache = {} }

    -- Build base views (skip entities marked for destruction)
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
    if avatar_ok and avatar and avatar.get then
      snapshot.active_avatar = avatar.get(world)
    end
    -- Backward-compat alias (avoid using in AI):
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

    ctx.set(snapshot)
  end

  return sys
end
