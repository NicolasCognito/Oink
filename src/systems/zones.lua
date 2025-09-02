package.path = table.concat({
  package.path,
  'libs/?.lua','libs/?/init.lua',
  'libs/tiny-ecs/?.lua','libs/tiny-ecs/?/init.lua',
  'src/?.lua','src/?/init.lua',
}, ';')

local tiny = require('tiny')

return function(opts)
  opts = opts or {}
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('zone', 'rect')

  function sys:preProcess(dt)
    -- Per-frame context snapshot with eager views and lazy queries
    local world = self.world
    local entities = world.entities
    local ctx = { world = world, dt = dt, _cache = {} }

    -- Eager: agents, collectables, zones
    local agents, collectables, zones = {}, {}, {}
    local ai, ci, zi = 1, 1, 1
    for i = 1, #entities do
      local e = entities[i]
      if e then
        if e.agent and e.pos then agents[ai] = e; ai = ai + 1 end
        if e.collectable then collectables[ci] = e; ci = ci + 1 end
        if e.zone then zones[zi] = e; zi = zi + 1 end
      end
    end
    ctx.agents = agents
    ctx.collectables = collectables
    ctx.zones = zones

    function ctx.query(name, predicate)
      -- Return cached if exists
      if ctx._cache[name] then return ctx._cache[name] end
      local list = {}
      local li = 1
      if name == 'agents' then
        list = ctx.agents
      elseif name == 'collectables' then
        list = ctx.collectables
      elseif name == 'zones' then
        list = ctx.zones
      else
        -- Build custom on demand
        local pred = predicate
        if not pred or type(pred) ~= 'function' then
          -- Fallback: match by field existence: e[name] truthy
          pred = function(e) return e and e[name] end
        end
        for j = 1, #entities do
          local ej = entities[j]
          if pred(ej) then list[li] = ej; li = li + 1 end
        end
      end
      ctx._cache[name] = list
      return list
    end

    self._ctx = ctx
  end

  function sys:process(zone, dt)
    -- Always tick zones every frame; zone decides what to do using ctx
    local ctx = self._ctx
    if zone.on_update then zone.on_update(zone, ctx) end
    if zone.on_tick then zone.on_tick(zone, ctx) end
  end

  return sys
end
