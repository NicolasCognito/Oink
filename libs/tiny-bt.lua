-- tiny-bt.lua — Behavior Trees for tiny-ecs
-- Public API:
--   local bt = require('tiny-bt')
--   local T = bt.dsl
--   local tree = bt.build(T.selector{
--       T.sequence{
--           T.condition{ name='HasTarget' },
--           T.action{ name='Chase', params={max_speed=120} },
--       },
--       T.action{ name='Idle' }
--   })
--   bt.register_condition('HasTarget', function(ctx) return ctx.entity.target ~= nil end)
--   bt.register_action('Chase', { tick=function(ctx, dt) /* ... */ return bt.RUNNING end })
--   bt.register_action('Idle',  { tick=function(ctx, dt) return bt.RUNNING end })
--   -- attach per-entity
--   enemy.bt = bt.instance(tree, {tick_interval=0.05, stagger=true, name='EnemyAI'})
--   -- add system once
--   world:addSystem(bt.system{ interval = nil }) -- or interval = 0.02 for global tick
--
-- Design: stateless shared tree + per-entity runtime state. Zero alloc per tick in steady state.

local tiny = require('tiny')

local bt = {}

-- Status enum (integers to avoid string churn)
bt.SUCCESS, bt.FAILURE, bt.RUNNING = 1, 2, 3

-- Node type tags
local SEQ, SEL, PAR, COND, ACT, DEC, SUB = 'Sequence','Selector','Parallel','Condition','Action','Decorator','Subtree'

-- Registries for leaf handlers
local CONDITIONS = {}
local ACTIONS    = {}

function bt.register_condition(name, fn)
    assert(type(name)=='string' and type(fn)=='function', 'bad condition')
    CONDITIONS[name] = fn
end

-- action = { start?=fn(ctx), tick=fn(ctx,dt)->status, abort?=fn(ctx), validate?=fn(ctx)->bool }
function bt.register_action(name, action)
    assert(type(name)=='string' and type(action)=='table' and type(action.tick)=='function', 'bad action')
    ACTIONS[name] = action
end

-- Blackboard: thin helpers over entity/world. Keep optional shared scope if needed later.
local Blackboard = {}
Blackboard.__index = Blackboard
function Blackboard.new(world, entity)
    return setmetatable({world=world, entity=entity}, Blackboard)
end
function Blackboard:has(key) return self.entity[key] ~= nil end
function Blackboard:get(key) return self.entity[key] end
function Blackboard:set(key, value) self.entity[key] = value end

-- DSL builders ---------------------------------------------------------------
local dsl = {}
bt.dsl = dsl

local function n(family, spec)
    spec = spec or {}
    spec._family = family
    return spec
end
function dsl.sequence(children) return n(SEQ, {children = children}) end
function dsl.selector(children) return n(SEL, {children = children}) end
function dsl.parallel(children, opts)
    opts = opts or {}
    local node = {children = children, success = opts.success, failure = opts.failure}
    return n(PAR, node)
end
function dsl.condition(spec)
    if type(spec) == 'function' then return n(COND, { _fn = spec }) end
    if type(spec) == 'table' and (spec.tick or spec._fn) then return n(COND, spec) end
    return n(COND, spec) -- {name=..., params=?}
end
function dsl.action(spec)
    if type(spec) == 'function' then return n(ACT, { _inline = { tick = spec } }) end
    if type(spec) == 'table' and (spec.tick or spec._inline) then return n(ACT, spec) end
    return n(ACT,  spec) -- {name=..., params=?}
end
function dsl.subtree(spec)
    return n(SUB, { tree_ref = spec })
end
-- Decorators
function dsl.inverter(child)   return n(DEC, {op='inverter', child=child}) end
function dsl.succeeder(child)  return n(DEC, {op='succeeder', child=child}) end
function dsl.failer(child)     return n(DEC, {op='failer', child=child}) end
function dsl.repeat_n(child, ncount) return n(DEC, {op='repeat', child=child, count=ncount}) end
function dsl.until_success(child) return n(DEC, {op='until_success', child=child}) end
function dsl.until_failure(child) return n(DEC, {op='until_failure', child=child}) end
function dsl.wait(seconds, child)  return n(DEC, {op='wait', child=child, seconds=seconds}) end
function dsl.cooldown(seconds, child) return n(DEC, {op='cooldown', child=child, seconds=seconds}) end
function dsl.time_limit(seconds, child) return n(DEC, {op='time_limit', child=child, seconds=seconds}) end

-- Build a compact tree asset (flat array of nodes) from DSL
function bt.build(rootSpec)
    local nodes = {}
    local function add(spec)
        local id = #nodes + 1
        local rec = {_id=id, type=spec._family}
        nodes[id] = rec
        if spec._family == SEQ or spec._family == SEL or spec._family == PAR then
            rec.children = {}
            if spec._family == PAR then
                rec.success = spec.success -- thresholds; defaults set later
                rec.failure = spec.failure
            end
            for i=1,#spec.children do
                local childId = add(spec.children[i])
                rec.children[i] = childId
            end
        elseif spec._family == DEC then
            rec.op = spec.op; rec.seconds = spec.seconds; rec.count = spec.count
            rec.child = add(spec.child)
        elseif spec._family == COND then
            if spec._fn or spec.tick then
                rec._cond_fn = spec._fn or spec.tick
            else
                rec.name = assert(spec.name, 'leaf needs name')
                rec.params = spec.params
            end
        elseif spec._family == ACT then
            if spec._inline or spec.tick then
                rec._act = spec._inline or spec -- inline action table { start?, tick, abort?, validate? }
            else
                rec.name = assert(spec.name, 'leaf needs name')
                rec.params = spec.params
            end
        elseif spec._family == SUB then
            rec.tree_ref = spec.tree_ref -- tree asset | function(owner)->tree
        else
            error('unknown node family: '..tostring(spec._family))
        end
        return id
    end
    local root = add(rootSpec)
    -- finalize defaults for parallel
    for i=1,#nodes do
        local n = nodes[i]
        if n.type==PAR then
            n.success = n.success or #n.children -- all succeed by default
            n.failure = n.failure or 1           -- any fail causes fail by default
        end
    end
    return {root=root, nodes=nodes}
end

-- Runtime instance per entity ------------------------------------------------
-- Returns component table to store on entity under field `bt`
function bt.instance(tree, opts)
    opts = opts or {}
    local count = #assert(tree.nodes)
    local st = {
        tree = tree,
        node_status = {},   -- [nodeId] => last status or nil
        node_mem    = {},   -- [nodeId] => small table per node; reused
        stack       = {},   -- reusable temp stack for traversal where needed
        tick_interval = opts.tick_interval, -- optional per-entity tick rate
        _acc = opts.stagger and math.random() * (opts.tick_interval or 0) or 0,
        name = opts.name,
        debug = opts.debug and {last_path=nil, counters={}} or nil,
    }
    -- Pre-warm mem tables
    for i=1,count do st.node_mem[i] = st.node_mem[i] or false end
    return st
end

-- System ---------------------------------------------------------------------
-- Create once and add to world. Optionally override filter or interval.
function bt.system(spec)
    spec = spec or {}
    local sys = tiny.processingSystem()
    sys.filter = spec.filter or tiny.requireAll('bt')
    sys.interval = spec.interval -- use tiny's buffered interval if desired
    sys.name = 'BTSystem'

    function sys:onAddToWorld(world)
        self.world = world
    end

    local function ctx_for(self, e, st, node)
        local ctx = st._ctx
        if not ctx then
            ctx = { world=self.world, entity=e, bb=Blackboard.new(self.world, e), tree=st.tree }
            st._ctx = ctx
        end
        ctx.node = node
        ctx.params = node.params
        ctx.state  = st.node_mem[node._id]
        return ctx
    end

    -- reset subtree: clear statuses and abort running actions
    local function reset_subtree(st, nodeId)
        local nodes = st.tree.nodes
        local stack = st.stack; stack[1]=nodeId; local top=1
        while top>0 do
            local id = stack[top]; top = top - 1
            st.node_status[id] = nil
            local mem = st.node_mem[id]
            if mem and mem.started and nodes[id].type==ACT then
                local node = nodes[id]
                local act = node._act or ACTIONS[node.name]
                if act and act.abort then
                    act.abort({world=sys.world, entity=st._ctx and st._ctx.entity, tree=st.tree, node=node, params=node.params, state=mem})
                end
            elseif mem and nodes[id].type==SUB and mem.sub_st then
                -- clear nested subtree instance
                mem.sub_st = nil
            end
            st.node_mem[id] = false
            local n = nodes[id]
            if n.children then
                for i=1,#n.children do top=top+1; stack[top]=n.children[i] end
            elseif n.child then
                top=top+1; stack[top]=n.child
            end
        end
    end

    local function set_status(st, id, status)
        st.node_status[id] = status
        return status
    end

    local function tick_node(self, e, st, id, dt)
        local nodes = st.tree.nodes
        local n = nodes[id]
        local mem = st.node_mem[id]
        if n.type == SEQ then
            if not mem then mem = {i=1}; st.node_mem[id]=mem end
            while mem.i <= #n.children do
                local child = n.children[mem.i]
                local r = tick_node(self, e, st, child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                if r == bt.FAILURE then
                    -- ensure child subtree reset before returning
                    reset_subtree(st, child)
                    mem.i = 1
                    return set_status(st, id, bt.FAILURE)
                end
                mem.i = mem.i + 1
            end
            mem.i = 1
            return set_status(st, id, bt.SUCCESS)

        elseif n.type == SEL then
            -- Reactive priority selector: reevaluate from first child every tick.
            if not mem then mem = {}; st.node_mem[id]=mem end
            for i=1,#n.children do
                local child = n.children[i]
                local r = tick_node(self, e, st, child, dt)
                if r == bt.SUCCESS then
                    -- Reset all other children to ensure clean restart next tick.
                    for j=1,#n.children do if j~=i then reset_subtree(st, n.children[j]) end end
                    mem.i = 1
                    return set_status(st, id, bt.SUCCESS)
                elseif r == bt.RUNNING then
                    -- Preempt lower-priority branches; reset them now.
                    for j=1,#n.children do if j~=i then reset_subtree(st, n.children[j]) end end
                    mem.i = i
                    return set_status(st, id, bt.RUNNING)
                else
                    -- FAILURE: reset this child and continue to next.
                    reset_subtree(st, child)
                end
            end
            mem.i = 1
            return set_status(st, id, bt.FAILURE)

        elseif n.type == PAR then
            if not mem then mem = {done={}, success=0, failure=0}; st.node_mem[id]=mem end
            local success, failure = 0, 0
            for idx=1,#n.children do
                if not mem.done[idx] then
                    local r = tick_node(self, e, st, n.children[idx], dt)
                    if r == bt.SUCCESS then
                        success = success + 1
                        mem.done[idx] = true
                        reset_subtree(st, n.children[idx])
                    elseif r == bt.FAILURE then
                        failure = failure + 1
                        mem.done[idx] = true
                        reset_subtree(st, n.children[idx])
                    end
                else
                    -- already terminal
                    if st.node_status[n.children[idx]] == bt.SUCCESS then success=success+1 else failure=failure+1 end
                end
            end
            if success >= n.success then
                -- reset remaining children
                for i=1,#n.children do if not mem.done[i] then reset_subtree(st, n.children[i]) end end
                st.node_mem[id] = false
                return set_status(st, id, bt.SUCCESS)
            end
            if failure >= n.failure then
                for i=1,#n.children do if not mem.done[i] then reset_subtree(st, n.children[i]) end end
                st.node_mem[id] = false
                return set_status(st, id, bt.FAILURE)
            end
            return set_status(st, id, bt.RUNNING)

        elseif n.type == DEC then
            local op = n.op
            if op == 'inverter' then
                local r = tick_node(self, e, st, n.child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                if r == bt.SUCCESS then reset_subtree(st, n.child); return set_status(st, id, bt.FAILURE) end
                if r == bt.FAILURE then reset_subtree(st, n.child); return set_status(st, id, bt.SUCCESS) end
            elseif op == 'succeeder' then
                local r = tick_node(self, e, st, n.child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                reset_subtree(st, n.child)
                return set_status(st, id, bt.SUCCESS)
            elseif op == 'failer' then
                local r = tick_node(self, e, st, n.child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                reset_subtree(st, n.child)
                return set_status(st, id, bt.FAILURE)
            elseif op == 'repeat' then
                if not mem then mem={count=0}; st.node_mem[id]=mem end
                local r = tick_node(self, e, st, n.child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                reset_subtree(st, n.child)
                mem.count = mem.count + 1
                if n.count and mem.count >= n.count then
                    st.node_mem[id] = false
                    return set_status(st, id, bt.SUCCESS)
                else
                    return set_status(st, id, bt.RUNNING) -- repeat forever if count missing
                end
            elseif op == 'until_success' or op=='until_failure' then
                local target = (op=='until_success') and bt.SUCCESS or bt.FAILURE
                local r = tick_node(self, e, st, n.child, dt)
                if r == target then
                    reset_subtree(st, n.child)
                    st.node_mem[id] = false
                    return set_status(st, id, bt.SUCCESS)
                elseif r ~= bt.RUNNING then
                    reset_subtree(st, n.child)
                end
                return set_status(st, id, bt.RUNNING)
            elseif op == 'wait' then
                if not mem then mem={t=0, gate_open=false}; st.node_mem[id]=mem end
                if not mem.gate_open then
                    mem.t = mem.t + dt
                    if mem.t >= (n.seconds or 0) then mem.gate_open=true end
                    return set_status(st, id, bt.RUNNING)
                end
                local r = tick_node(self, e, st, n.child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                reset_subtree(st, n.child)
                st.node_mem[id] = false
                return set_status(st, id, r)
            elseif op == 'cooldown' then
                if not mem then mem={t=0, until_ready=0}; st.node_mem[id]=mem end
                if mem.until_ready > 0 then
                    mem.t = mem.t + dt
                    if mem.t < mem.until_ready then
                        return set_status(st, id, bt.FAILURE) -- still cooling
                    end
                    mem.t, mem.until_ready = 0, 0
                end
                local r = tick_node(self, e, st, n.child, dt)
                if r == bt.RUNNING then return set_status(st, id, bt.RUNNING) end
                if r == bt.SUCCESS then mem.until_ready = n.seconds or 0 end
                reset_subtree(st, n.child)
                return set_status(st, id, r)
            elseif op == 'time_limit' then
                if not mem then mem={t=0}; st.node_mem[id]=mem end
                mem.t = mem.t + dt
                if mem.t > (n.seconds or 0) then
                    reset_subtree(st, n.child)
                    st.node_mem[id] = false
                    return set_status(st, id, bt.FAILURE)
                end
                local r = tick_node(self, e, st, n.child, dt)
                if r ~= bt.RUNNING then
                    reset_subtree(st, n.child)
                    st.node_mem[id] = false
                end
                return set_status(st, id, r)
            else
                error('unknown decorator op: '..tostring(op))
            end

        elseif n.type == COND then
            local ctx = ctx_for(self, e, st, n)
            local ok
            if n._cond_fn then
                ok = n._cond_fn(ctx) and true or false
            else
                local cond = assert(CONDITIONS[n.name], 'unregistered condition '..tostring(n.name))
                ok = cond(ctx) and true or false
            end
            return set_status(st, id, ok and bt.SUCCESS or bt.FAILURE)

        elseif n.type == ACT then
            local act = n._act or ACTIONS[n.name]
            assert(act and act.tick, 'unregistered action '..tostring(n.name or '<inline>'))
            local ctx = ctx_for(self, e, st, n)
            if not mem then mem = {started=false}; st.node_mem[id]=mem end
            if not mem.started then
                if act.validate and act.validate(ctx) == false then
                    return set_status(st, id, bt.FAILURE)
                end
                if act.start then act.start(ctx) end
                mem.started = true
            end
            ctx.state = mem
            local r = act.tick(ctx, dt)
            if r ~= bt.RUNNING then
                if r ~= bt.SUCCESS and act.abort then act.abort(ctx) end
                st.node_mem[id] = false
            end
            return set_status(st, id, r)
        elseif n.type == SUB then
            if not mem then mem = {}; st.node_mem[id]=mem end
            -- resolve tree
            local tree
            if type(n.tree_ref)=='function' then tree = n.tree_ref(e) else tree = n.tree_ref end
            if not tree then return set_status(st, id, bt.FAILURE) end
            if not mem.sub_st or mem.sub_st.tree ~= tree then
                mem.sub_st = { tree = tree, node_status = {}, node_mem = {}, stack = {}, _ctx = nil }
            end
            local sub = mem.sub_st
            local r = tick_node(self, e, sub, tree.root, dt)
            if r ~= bt.RUNNING then
                -- reset on finish
                for i=1,#tree.nodes do sub.node_status[i]=nil; sub.node_mem[i]=false end
                mem.sub_st = nil
            end
            return set_status(st, id, r)
        else
            error('unknown node type '..tostring(n.type))
        end
    end

    function sys:process(e, dt)
        local st = e.bt; if not st then return end
        -- per-entity interval
        local step = st.tick_interval
        if step and step > 0 then
            st._acc = (st._acc or 0) + dt
            while st._acc >= step do
                st._acc = st._acc - step
                tick_node(self, e, st, st.tree.root, step)
            end
        else
            tick_node(self, e, st, st.tree.root, dt)
        end
    end

    return sys
end

-- Introspection helpers ------------------------------------------------------
function bt.last_status(e)
    local st = e.bt; if not st then return nil end
    return st.node_status[st.tree.root]
end

function bt.dump_status(e)
    local st = e.bt; if not st then return '' end
    local lines = {}
    local nodes = st.tree.nodes
    for i=1,#nodes do
        local s = st.node_status[i]
        local tag = s==bt.SUCCESS and 'S' or s==bt.FAILURE and 'F' or s==bt.RUNNING and 'R' or '-'
        lines[#lines+1] = string.format('%3d %-10s %s %s', i, nodes[i].type, nodes[i].name or nodes[i].op or '', tag)
    end
    return table.concat(lines, '\n')
end

return bt
