-- tiny-fsm.lua — Finite State Machines for tiny-ecs / LÖVE
--
-- Domain note
--  * FSMs here are for simple mechanical or ambient logic (doors, traps, buildings, UI, props, cards in HS-like games).
--  * Do NOT use for agent AI. Use your Behavior Trees plugin for agents and decision making.
--
-- Design goals
--  * Pure data in components. All logic runs in a tiny system.
--  * Zero-garbage steady state. Reuse per-entity tables.
--  * Declarative states and transitions. No per-entity closures.
--  * Optional per-entity tick interval, stagger support.
--
-- Public API
--  local fsm = require('tiny-fsm')
--  -- 1) Register reusable logic once (non-agent example)
--  fsm.register_action('BootSequence', {
--      enter=function(ctx) ctx.entity.boot_t = 0 end,
--      update=function(ctx, dt)
--          ctx.entity.boot_t = ctx.entity.boot_t + dt
--          if ctx.entity.boot_t > 2 then return 'online' end
--      end,
--  })
--  fsm.register_condition('HasPower', function(ctx)
--      return ctx.entity.has_power == true
--  end)
--
--  -- 2) Build a machine asset (shared), e.g., a power plant controller
--  local Plant = fsm.build({
--      initial = 'offline',
--      states = {
--          offline = {
--              transitions = {
--                  { if_='HasPower', to='booting', priority=10, interrupt=true },
--              }
--          },
--          booting = {
--              action = 'BootSequence',
--          },
--          online = {
--              on_update = function(ctx, dt)
--                  ctx.entity.stock = (ctx.entity.stock or 0) + dt * (ctx.entity.rate or 1)
--                  if not ctx.entity.has_power then return 'offline' end
--              end,
--          },
--      }
--  })
--
--  -- 3) Per-entity instance stored on entity.fsm
--  plantEntity.fsm = fsm.instance(Plant, { tick_interval=0.05, stagger=true, name='PlantFSM' })
--
--  -- 4) Add system once
--  world:addSystem(fsm.system{ interval=nil })
--
--  -- 5) External control
--  -- fsm.set(plantEntity, 'offline')
--  -- fsm.push_event(plantEntity, 'alarm', {code=3})
--
-- Notes:
--  * States can declare logic either inline (on_enter/on_update/on_exit) or by `action='Name'` from registry.
--  * Transitions support: if_ = 'CondName' | function(ctx)->bool, to = 'state', priority=?, interrupt=?
--  * on_update can return a state name for direct transition (wins over transitions list when non-nil).

local tiny = require('tiny')

local fsm = {}

-- Registries ---------------------------------------------------------------
local ACTIONS = {}
local CONDITIONS = {}

-- action = { enter?=fn(ctx), update?=fn(ctx,dt), exit?=fn(ctx) }
function fsm.register_action(name, tbl)
    assert(type(name)=='string' and type(tbl)=='table', 'bad action')
    ACTIONS[name] = tbl
end

function fsm.register_condition(name, fn)
    assert(type(name)=='string' and type(fn)=='function', 'bad condition')
    CONDITIONS[name] = fn
end

-- Helpers to invoke registered items by name from user inline fns -------------
function fsm.call(kind, ctx)
    local c = CONDITIONS[kind]
    if not c then error('unknown condition '..tostring(kind)) end
    return c(ctx)
end

-- Context object ------------------------------------------------------------
local Ctx = {}
Ctx.__index = Ctx
function Ctx.new(world, entity, st)
    return setmetatable({world=world, entity=entity, _st=st, params=nil, state_name=nil}, Ctx)
end

-- Build machine asset -------------------------------------------------------
-- spec = { initial='idle', states={ [name]={ action='Name' | {enter,update,exit},
--                                          on_enter=fn?, on_update=fn?, on_exit=fn?,
--                                          transitions={ {if_=name|fn, to='name', priority=int?, interrupt=bool?, params=?}... } } } }
function fsm.build(spec)
    assert(type(spec)=='table' and type(spec.states)=='table', 'fsm.build: bad spec')
    local states, order, index = {}, {}, {}
    local i = 0
    for name, def in pairs(spec.states) do
        i=i+1; order[i]=name; index[name]=i
        local s = { name=name, transitions={}, enter=nil, update=nil, exit=nil }
        -- normalize action shorthands
        if type(def.action)=='string' then
            local a = ACTIONS[def.action]; assert(a, 'action '..def.action..' not registered')
            s.enter, s.update, s.exit = a.enter, a.update, a.exit
        end
        -- explicit hooks win
        s.enter = def.on_enter or s.enter
        s.update = def.on_update or s.update
        s.exit  = def.on_exit  or s.exit
        -- transitions array
        local tlist = def.transitions or {}
        for ti=1,#tlist do
            local t = tlist[ti]
            local cond = t.if_
            local condT, condV = type(cond), cond
            if condT == 'string' then
                condV = CONDITIONS[cond]; assert(condV, 'condition '..cond..' not registered')
            elseif condT ~= 'function' then
                error('transition.if_ must be string or function')
            end
            s.transitions[#s.transitions+1] = {
                cond = condV,
                to = assert(t.to, 'transition needs target state'),
                priority = t.priority or 0,
                interrupt = t.interrupt and true or false,
                params = t.params
            }
        end
        -- sort transitions by priority desc
        table.sort(s.transitions, function(a,b) return a.priority>b.priority end)
        states[i] = s
    end
    assert(spec.initial and index[spec.initial], 'fsm.build: missing or unknown initial state')
    return { _kind='fsm_asset', states=states, index=index, order=order, initial=spec.initial }
end

-- Per-entity instance -------------------------------------------------------
function fsm.instance(asset, opts)
    assert(asset and asset._kind=='fsm_asset', 'fsm.instance: pass asset from fsm.build')
    opts = opts or {}
    local st = {
        asset = asset,
        current = asset.initial,
        previous = nil,
        timer = 0,
        mem = {},           -- per-state scratch tables, keyed by state name
        queue = {},         -- pending events as array of {name, data}; reused
        _qhead = 1, _qtail = 0,
        tick_interval = opts.tick_interval,
        _acc = opts.stagger and math.random() * (opts.tick_interval or 0) or 0,
        name = opts.name,
        _ctx = false,
    }
    return st
end

-- External signals ----------------------------------------------------------
function fsm.push_event(e, name, data)
    local st = e.fsm; if not st then return end
    st._qtail = st._qtail + 1
    local i = st._qtail
    local q = st.queue
    local item = q[i]
    if item then item[1], item[2] = name, data else q[i] = {name, data} end
end

function fsm.set(e, state)
    local st = e.fsm; if not st then return end
    local asset = st.asset
    assert(asset.index[state], 'fsm.set: unknown state '..tostring(state))
    st._force = state
end

function fsm.state(e)
    local st = e.fsm; return st and st.current or nil
end

-- Transition machinery ------------------------------------------------------
local function do_exit(ctx, sdef)
    if sdef.exit then sdef.exit(ctx) end
end
local function do_enter(ctx, sdef)
    if sdef.enter then sdef.enter(ctx) end
end

local function transition_to(world, e, st, to)
    if to == st.current then return false end
    local asset = st.asset
    local cur = st.current
    local curDef = asset.states[ asset.index[cur] ]
    local ctx = st._ctx or Ctx.new(world, e, st); st._ctx = ctx
    ctx.state_name = cur
    do_exit(ctx, curDef)
    st.previous = cur
    st.current = to
    st.timer = 0
    ctx.state_name = to
    local toDef = asset.states[ asset.index[to] ]
    do_enter(ctx, toDef)
    return true
end

-- Evaluate transitions list. Returns target state name or nil.
local function eval_transitions(world, e, st, sdef, dt, interrupts_only)
    local ctx = st._ctx or Ctx.new(world, e, st); st._ctx = ctx
    ctx.state_name = sdef.name
    -- feed pending events if user logic reads them
    ctx.next_event = nil
    if st._qhead <= st._qtail then
        ctx.next_event = st.queue[st._qhead] -- {name, data}
    end
    for i=1,#sdef.transitions do
        local t = sdef.transitions[i]
        if not interrupts_only or t.interrupt then
            ctx.params = t.params
            if t.cond(ctx) then return t.to end
        end
    end
    return nil
end

-- The System ---------------------------------------------------------------
function fsm.system(spec)
    spec = spec or {}
    local sys = tiny.processingSystem()
    sys.filter = spec.filter or tiny.requireAll('fsm')
    sys.interval = spec.interval
    sys.name = 'FSMSystem'

    function sys:onAddToWorld(world) self.world = world end

    local function process_machine(self, e, st, dt)
        local asset = st.asset
        local idx = asset.index
        local sdef = asset.states[ idx[ st.current ] ]
        -- interrupts first
        local to = eval_transitions(self.world, e, st, sdef, dt, true)
        if not to and sdef.update then
            local ctx = st._ctx or Ctx.new(self.world, e, st); st._ctx = ctx
            ctx.state_name, ctx.params = st.current, nil
            local ret = sdef.update(ctx, dt)
            if type(ret)=='string' and idx[ret] then to = ret end
        end
        if not to then
            to = eval_transitions(self.world, e, st, sdef, dt, false)
        end
        if st._force then to = st._force; st._force=nil end
        if to then
            transition_to(self.world, e, st, to)
            -- consume one queued event if any
            if st._qhead <= st._qtail then st._qhead = st._qhead + 1 end
        else
            -- if update did not change state, advance timer
            st.timer = st.timer + dt
            -- clear consumed event marker if user popped it in update
            if st._qhead <= st._qtail then
                local ev = st.queue[st._qhead]
                if ev and ev[3]==true then st._qhead = st._qhead + 1 end
            end
        end
        -- compact queue if empty
        if st._qhead>st._qtail then st._qhead, st._qtail = 1, 0 end
    end

    function sys:process(e, dt)
        local st = e.fsm; if not st then return end
        local step = st.tick_interval
        if step and step>0 then
            st._acc = (st._acc or 0) + dt
            while st._acc >= step do
                st._acc = st._acc - step
                process_machine(self, e, st, step)
            end
        else
            process_machine(self, e, st, dt)
        end
    end

    return sys
end

-- Utilities -----------------------------------------------------------------
-- Allow user update code to mark the current pending event as consumed
function fsm.pop_event(e)
    local st = e.fsm; if not st then return nil end
    if st._qhead <= st._qtail then
        local ev = st.queue[st._qhead]
        ev[3] = true -- mark consumed for this tick
        return ev[1], ev[2]
    end
    return nil
end

-- Debug helpers -------------------------------------------------------------
function fsm.dump(e)
    local st = e.fsm; if not st then return '' end
    return string.format('[FSM %s] current=%s prev=%s t=%.3f q=%d',
        st.name or '', tostring(st.current), tostring(st.previous), st.timer, st._qtail-st._qhead+1)
end

return fsm
