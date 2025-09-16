-- tiny-bt-tasks-v3.lua – Task-Based Behavior Trees for tiny-ecs with Subtree Support
-- Subtrees are now a first-class node type alongside sequences, selectors, etc.

local tiny = require('tiny')

local bt = {}

-- Status enum
bt.SUCCESS, bt.FAILURE, bt.RUNNING = 1, 2, 3

-- Node types
local SEQ, SEL, PAR, COND, TASK, DEC, SUBTREE = 
    'Sequence','Selector','Parallel','Condition','Task','Decorator','Subtree'

-- Registries
local CONDITIONS = {}
local TASKS = {}
local TREES = {}  -- Named tree registry for subtrees

-- Register a condition (pure function, returns boolean)
function bt.register_condition(name, fn)
    assert(type(name) == 'string' and type(fn) == 'function', 'bad condition')
    CONDITIONS[name] = fn
end

-- Register a task (spawns entities)
-- task = {
--   spawn = function(owner_entity, world, params) -> task_entity,
--   validate? = function(owner_entity, params) -> boolean
-- }
function bt.register_task(name, task_def)
    assert(type(name) == 'string' and type(task_def) == 'table' and type(task_def.spawn) == 'function', 'bad task')
    TASKS[name] = task_def
end

-- Register a named tree for use in subtrees
function bt.register_tree(name, tree)
    assert(type(name) == 'string' and type(tree) == 'table', 'bad tree registration')
    TREES[name] = tree
end

-- Get a registered tree
function bt.get_tree(name)
    return TREES[name]
end

-- DSL builders
local dsl = {}
bt.dsl = dsl

local function make_node(family, spec)
    spec = spec or {}
    spec._family = family
    return spec
end

function dsl.sequence(children)
    return make_node(SEQ, {children = children})
end

function dsl.selector(children)
    return make_node(SEL, {children = children})
end

function dsl.parallel(children, opts)
    opts = opts or {}
    return make_node(PAR, {
        children = children,
        success = opts.success,  -- # of successes needed
        failure = opts.failure   -- # of failures to fail
    })
end

function dsl.condition(name, params)
    return make_node(COND, {name = name, params = params})
end

-- Task nodes spawn entities
function dsl.task(name, params)
    return make_node(TASK, {name = name, params = params})
end

-- Subtree node - executes another behavior tree
-- Can accept either:
-- 1. A tree object directly: dsl.subtree(my_tree)
-- 2. A registered tree name: dsl.subtree('combat')
-- 3. A function that returns a tree: dsl.subtree(function(entity) return entity.custom_tree end)
function dsl.subtree(tree_or_name_or_fn, params)
    return make_node(SUBTREE, {tree_ref = tree_or_name_or_fn, params = params})
end

-- Decorators
function dsl.inverter(child)      return make_node(DEC, {op = 'inverter', child = child}) end
function dsl.succeeder(child)     return make_node(DEC, {op = 'succeeder', child = child}) end
function dsl.failer(child)        return make_node(DEC, {op = 'failer', child = child}) end
function dsl.repeat_n(child, c)   return make_node(DEC, {op = 'repeat', child = child, count = c}) end
function dsl.until_success(child) return make_node(DEC, {op = 'until_success', child = child}) end
function dsl.until_failure(child) return make_node(DEC, {op = 'until_failure', child = child}) end
function dsl.wait(seconds, child) return make_node(DEC, {op = 'wait', child = child, seconds = seconds}) end
function dsl.cooldown(seconds, child) return make_node(DEC, {op = 'cooldown', child = child, seconds = seconds}) end
function dsl.time_limit(seconds, child) return make_node(DEC, {op = 'time_limit', child = child, seconds = seconds}) end

-- Build tree from DSL
function bt.build(root_spec)
    local nodes = {}

    local function add_node(spec)
        local id = #nodes + 1
        local node = {_id = id, type = spec._family}
        nodes[id] = node

        if spec._family == SEQ or spec._family == SEL or spec._family == PAR then
            node.children = {}
            if spec._family == PAR then
                node.success = spec.success
                node.failure = spec.failure
            end
            for i = 1, #spec.children do
                node.children[i] = add_node(spec.children[i])
            end
        elseif spec._family == DEC then
            node.op = spec.op
            node.count = spec.count
            node.seconds = spec.seconds
            node.child = add_node(spec.child)
        elseif spec._family == SUBTREE then
            node.tree_ref = spec.tree_ref
            node.params = spec.params
        elseif spec._family == COND or spec._family == TASK then
            node.name = assert(spec.name, 'leaf needs name')
            node.params = spec.params
        else
            error('unknown node family: ' .. tostring(spec._family))
        end

        return id
    end

    local root = add_node(root_spec)

    -- Set defaults for parallel nodes
    for i = 1, #nodes do
        local n = nodes[i]
        if n.type == PAR then
            n.success = n.success or #n.children
            n.failure = n.failure or 1
        end
    end

    return {root = root, nodes = nodes}
end

-- Create instance for an entity
function bt.instance(tree, opts)
    opts = opts or {}
    return {
        tree = tree,
        current_node = tree.root,
        node_states = {},     -- [node_id] = {status, task_entity, child_index, ...decorator mem}
        subtree_instances = {},  -- [node_id] = subtree_instance
        waiting_for_task = false,
        active_task = nil,    -- Current task entity we're waiting on
        tick_interval = opts.tick_interval,
        _acc = opts.stagger and math.random() * (opts.tick_interval or 0) or 0,
        name = opts.name,
        debug = opts.debug
    }
end

-- Public reset utility so cancel works outside the system closure
local function reset_subtree_public(st, node_id)
    local nodes = st.tree.nodes
    local stack = {node_id}
    while #stack > 0 do
        local id = table.remove(stack)
        local state = st.node_states[id]
        if state and state.task_entity then
            state.task_entity.task_cancelled = true
            state.task_entity = nil
        end
        st.node_states[id] = nil
        
        -- Clean up subtree instances
        if st.subtree_instances[id] then
            local sub_st = st.subtree_instances[id]
            reset_subtree_public(sub_st, sub_st.tree.root)
            st.subtree_instances[id] = nil
        end
        
        local node = nodes[id]
        if node.children then
            for _, child_id in ipairs(node.children) do
                table.insert(stack, child_id)
            end
        elseif node.child then
            table.insert(stack, node.child)
        end
    end
end
bt._reset_subtree = reset_subtree_public

-- Main BT System
function bt.system(spec)
    spec = spec or {}
    local sys = tiny.processingSystem()
    sys.filter = spec.filter or tiny.requireAll('bt')
    sys.interval = spec.interval
    sys.name = 'BTSystem'

    function sys:onAddToWorld(world)
        self.world = world
    end

    -- Process a single node
    local function tick_node(world, entity, st, node_id, dt)
        local nodes = st.tree.nodes
        local node = nodes[node_id]
        local state = st.node_states[node_id] or {}
        st.node_states[node_id] = state

        -- If we're waiting on a task, check if it's complete
        if state.task_entity then
            if state.task_entity.task_complete then
                local result = state.task_entity.task_result or bt.SUCCESS
                world:removeEntity(state.task_entity)
                state.task_entity = nil
                state.status = result
                return result
            else
                return bt.RUNNING
            end
        end

        if node.type == SEQ then
            state.child_index = state.child_index or 1
            while state.child_index <= #node.children do
                local child_id = node.children[state.child_index]
                local result = tick_node(world, entity, st, child_id, dt)
                if result == bt.RUNNING then
                    return bt.RUNNING
                elseif result == bt.FAILURE then
                    reset_subtree_public(st, child_id)
                    state.child_index = 1
                    return bt.FAILURE
                else -- SUCCESS
                    state.child_index = state.child_index + 1
                end
            end
            state.child_index = 1
            return bt.SUCCESS

        elseif node.type == SEL then
            state.child_index = state.child_index or 1
            while state.child_index <= #node.children do
                local child_id = node.children[state.child_index]
                local result = tick_node(world, entity, st, child_id, dt)
                if result == bt.RUNNING then
                    return bt.RUNNING
                elseif result == bt.SUCCESS then
                    -- Reset failed branches
                    for i = 1, state.child_index - 1 do
                        reset_subtree_public(st, node.children[i])
                    end
                    state.child_index = 1
                    return bt.SUCCESS
                else -- FAILURE
                    reset_subtree_public(st, child_id)
                    state.child_index = state.child_index + 1
                end
            end
            state.child_index = 1
            return bt.FAILURE

        elseif node.type == PAR then
            -- Initialize parallel state
            if not state.results then
                state.results = {}
                -- Touch all children once to kick off their work
                for i, child_id in ipairs(node.children) do
                    local result = tick_node(world, entity, st, child_id, dt)
                    if result ~= bt.RUNNING then
                        state.results[i] = result
                    end
                end
            end

            -- Check child progress
            local success_count, failure_count = 0, 0
            for i, child_id in ipairs(node.children) do
                if not state.results[i] then
                    local result = tick_node(world, entity, st, child_id, dt)
                    if result ~= bt.RUNNING then
                        state.results[i] = result
                    end
                end
                if state.results[i] == bt.SUCCESS then success_count = success_count + 1 end
                if state.results[i] == bt.FAILURE then failure_count = failure_count + 1 end
            end

            -- Completion conditions
            if success_count >= (node.success or #node.children) then
                for i, child_id in ipairs(node.children) do
                    if not state.results[i] then reset_subtree_public(st, child_id) end
                end
                state.results = nil
                return bt.SUCCESS
            elseif failure_count >= (node.failure or 1) then
                for i, child_id in ipairs(node.children) do
                    if not state.results[i] then reset_subtree_public(st, child_id) end
                end
                state.results = nil
                return bt.FAILURE
            else
                return bt.RUNNING
            end

        elseif node.type == COND then
            local cond_fn = assert(CONDITIONS[node.name], 'unregistered condition: ' .. node.name)
            local ok = cond_fn(entity, node.params) and true or false
            return ok and bt.SUCCESS or bt.FAILURE

        elseif node.type == TASK then
            local task_def = assert(TASKS[node.name], 'unregistered task: ' .. node.name)
            if task_def.validate and not task_def.validate(entity, node.params) then
                return bt.FAILURE
            end
            local task_entity = task_def.spawn(entity, world, node.params)
            if not task_entity then return bt.FAILURE end
            task_entity.bt_task = true
            task_entity.bt_owner = entity
            task_entity.bt_node = node_id
            state.task_entity = task_entity
            return bt.RUNNING

        elseif node.type == SUBTREE then
            -- Get the actual tree to execute
            local tree_to_run
            local tree_ref = node.tree_ref
            
            if type(tree_ref) == 'string' then
                -- Named tree from registry
                tree_to_run = assert(TREES[tree_ref], 'unregistered tree: ' .. tree_ref)
            elseif type(tree_ref) == 'function' then
                -- Dynamic tree from function
                tree_to_run = tree_ref(entity, node.params)
                assert(tree_to_run, 'subtree function returned nil')
            else
                -- Direct tree reference
                tree_to_run = tree_ref
            end
            
            -- Get or create subtree instance
            if not st.subtree_instances[node_id] then
                st.subtree_instances[node_id] = {
                    tree = tree_to_run,
                    current_node = tree_to_run.root,
                    node_states = {},
                    subtree_instances = {},  -- Subtrees can have subtrees!
                    name = (st.name or 'tree') .. '.sub' .. node_id
                }
            end
            
            local sub_st = st.subtree_instances[node_id]
            
            -- Check if tree changed (for dynamic trees)
            if sub_st.tree ~= tree_to_run then
                -- Tree changed, reset the old one and switch
                reset_subtree_public(sub_st, sub_st.tree.root)
                sub_st.tree = tree_to_run
                sub_st.current_node = tree_to_run.root
                sub_st.node_states = {}
                sub_st.subtree_instances = {}
            end
            
            -- Tick the subtree
            local result = tick_node(world, entity, sub_st, sub_st.tree.root, dt)
            
            -- Clean up if subtree finished
            if result ~= bt.RUNNING then
                reset_subtree_public(sub_st, sub_st.tree.root)
                st.subtree_instances[node_id] = nil
            end
            
            return result

        elseif node.type == DEC then
            if node.op == 'inverter' then
                local r = tick_node(world, entity, st, node.child, dt)
                if r == bt.RUNNING then return bt.RUNNING end
                reset_subtree_public(st, node.child)
                return (r == bt.SUCCESS) and bt.FAILURE or bt.SUCCESS

            elseif node.op == 'succeeder' then
                local r = tick_node(world, entity, st, node.child, dt)
                if r == bt.RUNNING then return bt.RUNNING end
                reset_subtree_public(st, node.child)
                return bt.SUCCESS

            elseif node.op == 'failer' then
                local r = tick_node(world, entity, st, node.child, dt)
                if r == bt.RUNNING then return bt.RUNNING end
                reset_subtree_public(st, node.child)
                return bt.FAILURE

            elseif node.op == 'repeat' then
                state.count = state.count or 0
                local r = tick_node(world, entity, st, node.child, dt)
                if r == bt.RUNNING then return bt.RUNNING end
                reset_subtree_public(st, node.child)
                state.count = state.count + 1
                if node.count and state.count >= node.count then
                    state.count = nil
                    return bt.SUCCESS
                else
                    return bt.RUNNING
                end

            elseif node.op == 'until_success' or node.op == 'until_failure' then
                local target = (node.op == 'until_success') and bt.SUCCESS or bt.FAILURE
                local r = tick_node(world, entity, st, node.child, dt)
                if r == target then
                    reset_subtree_public(st, node.child)
                    state.count, state.t, state.gate_open, state.until_ready = nil, nil, nil, nil
                    return bt.SUCCESS
                elseif r ~= bt.RUNNING then
                    reset_subtree_public(st, node.child)
                end
                return bt.RUNNING

            elseif node.op == 'wait' then
                state.t = state.t or 0
                state.gate_open = state.gate_open or false
                if not state.gate_open then
                    state.t = state.t + dt
                    if state.t >= (node.seconds or 0) then state.gate_open = true end
                    return bt.RUNNING
                end
                local r = tick_node(world, entity, st, node.child, dt)
                if r == bt.RUNNING then return bt.RUNNING end
                reset_subtree_public(st, node.child)
                state.t, state.gate_open = nil, nil
                return r

            elseif node.op == 'cooldown' then
                state.t = state.t or 0
                state.until_ready = state.until_ready or 0
                if state.until_ready > 0 then
                    state.t = state.t + dt
                    if state.t < state.until_ready then
                        return bt.FAILURE -- still cooling
                    end
                    state.t, state.until_ready = 0, 0
                end
                local r = tick_node(world, entity, st, node.child, dt)
                if r == bt.RUNNING then return bt.RUNNING end
                if r == bt.SUCCESS then state.until_ready = node.seconds or 0 end
                reset_subtree_public(st, node.child)
                return r

            elseif node.op == 'time_limit' then
                state.t = (state.t or 0) + dt
                if state.t > (node.seconds or 0) then
                    reset_subtree_public(st, node.child)
                    state.t = nil
                    return bt.FAILURE
                end
                local r = tick_node(world, entity, st, node.child, dt)
                if r ~= bt.RUNNING then
                    reset_subtree_public(st, node.child)
                    state.t = nil
                end
                return r

            else
                error('unknown decorator op: ' .. tostring(node.op))
            end
        end

        error('unhandled node type: ' .. tostring(node.type))
    end

    function sys:process(entity, dt)
        local st = entity.bt
        if not st then return end

        -- Handle tick interval
        if st.tick_interval then
            st._acc = (st._acc or 0) + dt
            if st._acc < st.tick_interval then
                return
            end
            st._acc = st._acc - st.tick_interval
        end

        -- Tick the tree from root
        tick_node(self.world, entity, st, st.tree.root, dt)
    end

    return sys
end

-- Example task system for movement
function bt.move_task_system()
    local sys = tiny.processingSystem()
    sys.filter = tiny.requireAll('task_type', 'target')
    sys.name = 'MoveTaskSystem'

    function sys:process(task_entity, dt)
        if task_entity.task_type ~= 'move' then return end
        if task_entity.task_cancelled then
            task_entity.task_complete = true
            task_entity.task_result = bt.FAILURE
            return
        end

        local owner = task_entity.owner
        if not owner or not owner.position then
            task_entity.task_complete = true
            task_entity.task_result = bt.FAILURE
            return
        end

        local target = task_entity.target
        local speed = task_entity.speed or 5.0

        -- Simple movement logic
        local dx = target.x - owner.position.x
        local dy = target.y - owner.position.y
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < 0.5 then
            task_entity.task_complete = true
            task_entity.task_result = bt.SUCCESS
        else
            local move_dist = speed * dt
            owner.position.x = owner.position.x + (dx/dist) * move_dist
            owner.position.y = owner.position.y + (dy/dist) * move_dist
        end
    end

    return sys
end

-- Helpers
function bt.is_running(entity)
    local st = entity.bt
    if not st then return false end
    return st.waiting_for_task or false
end

function bt.cancel(entity)
    local st = entity.bt
    if not st then return end
    reset_subtree_public(st, st.tree.root)
end

return bt