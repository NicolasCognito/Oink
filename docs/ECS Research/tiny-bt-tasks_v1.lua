-- tiny-bt-tasks.lua – Task-Based Behavior Trees for tiny-ecs
-- 
-- Key Design: Action nodes spawn task entities that execute independently.
-- The BT monitors task completion and resumes when tasks finish.
--
-- Public API:
--   local bt = require('tiny-bt-tasks')
--   local T = bt.dsl
--   
--   local tree = bt.build(T.selector{
--       T.sequence{
--           T.condition('HasTarget'),
--           T.task('MoveToTarget'),
--           T.task('AttackTarget')
--       },
--       T.task('Patrol')
--   })
--   
--   bt.register_condition('HasTarget', function(entity) 
--       return entity.target ~= nil 
--   end)
--   
--   bt.register_task('MoveToTarget', {
--       spawn = function(entity, world)
--           return world:addEntity({
--               task_type = 'move',
--               owner = entity,
--               target = entity.target,
--               speed = 5.0
--           })
--       end
--   })
--   
--   enemy.bt = bt.instance(tree)
--   world:addSystem(bt.system())
--   world:addSystem(bt.move_task_system())  -- Process move tasks

local tiny = require('tiny')

local bt = {}

-- Status enum
bt.SUCCESS, bt.FAILURE, bt.RUNNING = 1, 2, 3

-- Node types
local SEQ, SEL, PAR, COND, TASK, DEC = 'Sequence','Selector','Parallel','Condition','Task','Decorator'

-- Registries
local CONDITIONS = {}
local TASKS = {}

-- Register a condition (pure function, returns boolean)
function bt.register_condition(name, fn)
    assert(type(name) == 'string' and type(fn) == 'function', 'bad condition')
    CONDITIONS[name] = fn
end

-- Register a task (spawns entities)
-- task = { 
--   spawn = function(owner_entity, world) -> task_entity,
--   validate? = function(owner_entity) -> boolean
-- }
function bt.register_task(name, task_def)
    assert(type(name) == 'string' and type(task_def) == 'table' and type(task_def.spawn) == 'function', 'bad task')
    TASKS[name] = task_def
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

-- Decorators
function dsl.inverter(child)
    return make_node(DEC, {op = 'inverter', child = child})
end

function dsl.succeeder(child)
    return make_node(DEC, {op = 'succeeder', child = child})
end

function dsl.repeat_n(child, count)
    return make_node(DEC, {op = 'repeat', child = child, count = count})
end

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
            node.child = add_node(spec.child)
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
        node_states = {},     -- [node_id] = {status, task_entity, child_index}
        waiting_for_task = false,
        active_task = nil,    -- Current task entity we're waiting on
        tick_interval = opts.tick_interval,
        _acc = opts.stagger and math.random() * (opts.tick_interval or 0) or 0,
        name = opts.name,
        debug = opts.debug
    }
end

-- Task completion event component
-- When a task completes, it adds this component to signal the BT
bt.TaskComplete = {}

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
    
    -- Reset a subtree's state
    local function reset_subtree(st, node_id)
        local nodes = st.tree.nodes
        local stack = {node_id}
        
        while #stack > 0 do
            local id = table.remove(stack)
            local state = st.node_states[id]
            
            -- Cancel any active task
            if state and state.task_entity then
                -- Add cancellation marker
                state.task_entity.task_cancelled = true
                state.task_entity = nil
            end
            
            st.node_states[id] = nil
            
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
    
    -- Process a single node
    local function tick_node(world, entity, st, node_id)
        local nodes = st.tree.nodes
        local node = nodes[node_id]
        local state = st.node_states[node_id] or {}
        st.node_states[node_id] = state
        
        -- If we're waiting on a task, check if it's complete
        if state.task_entity then
            if state.task_entity.task_complete then
                local result = state.task_entity.task_result or bt.SUCCESS
                
                -- Clean up task entity
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
                local result = tick_node(world, entity, st, child_id)
                
                if result == bt.RUNNING then
                    return bt.RUNNING
                elseif result == bt.FAILURE then
                    reset_subtree(st, child_id)
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
                local result = tick_node(world, entity, st, child_id)
                
                if result == bt.RUNNING then
                    return bt.RUNNING
                elseif result == bt.SUCCESS then
                    -- Reset failed branches
                    for i = 1, state.child_index - 1 do
                        reset_subtree(st, node.children[i])
                    end
                    state.child_index = 1
                    return bt.SUCCESS
                else -- FAILURE
                    reset_subtree(st, child_id)
                    state.child_index = state.child_index + 1
                end
            end
            
            state.child_index = 1
            return bt.FAILURE
            
        elseif node.type == PAR then
            -- Initialize parallel state
            if not state.task_entities then
                state.task_entities = {}
                state.results = {}
                
                -- Spawn all child tasks
                for i, child_id in ipairs(node.children) do
                    local result = tick_node(world, entity, st, child_id)
                    if result ~= bt.RUNNING then
                        state.results[i] = result
                    end
                end
            end
            
            -- Check child progress
            local success_count = 0
            local failure_count = 0
            local running_count = 0
            
            for i, child_id in ipairs(node.children) do
                if not state.results[i] then
                    local result = tick_node(world, entity, st, child_id)
                    if result ~= bt.RUNNING then
                        state.results[i] = result
                    else
                        running_count = running_count + 1
                    end
                end
                
                if state.results[i] == bt.SUCCESS then
                    success_count = success_count + 1
                elseif state.results[i] == bt.FAILURE then
                    failure_count = failure_count + 1
                end
            end
            
            -- Check completion conditions
            if success_count >= (node.success or #node.children) then
                -- Cancel remaining tasks
                for i, child_id in ipairs(node.children) do
                    if not state.results[i] then
                        reset_subtree(st, child_id)
                    end
                end
                state.task_entities = nil
                state.results = nil
                return bt.SUCCESS
            elseif failure_count >= (node.failure or 1) then
                -- Cancel remaining tasks
                for i, child_id in ipairs(node.children) do
                    if not state.results[i] then
                        reset_subtree(st, child_id)
                    end
                end
                state.task_entities = nil
                state.results = nil
                return bt.FAILURE
            else
                return bt.RUNNING
            end
            
        elseif node.type == COND then
            local cond_fn = assert(CONDITIONS[node.name], 'unregistered condition: ' .. node.name)
            local success = cond_fn(entity, node.params)
            return success and bt.SUCCESS or bt.FAILURE
            
        elseif node.type == TASK then
            local task_def = assert(TASKS[node.name], 'unregistered task: ' .. node.name)
            
            -- Validate if needed
            if task_def.validate and not task_def.validate(entity, node.params) then
                return bt.FAILURE
            end
            
            -- Spawn the task entity
            local task_entity = task_def.spawn(entity, world, node.params)
            if not task_entity then
                return bt.FAILURE
            end
            
            -- Mark task with metadata
            task_entity.bt_task = true
            task_entity.bt_owner = entity
            task_entity.bt_node = node_id
            
            state.task_entity = task_entity
            return bt.RUNNING
            
        elseif node.type == DEC then
            if node.op == 'inverter' then
                local result = tick_node(world, entity, st, node.child)
                if result == bt.RUNNING then return bt.RUNNING end
                reset_subtree(st, node.child)
                return result == bt.SUCCESS and bt.FAILURE or bt.SUCCESS
                
            elseif node.op == 'succeeder' then
                local result = tick_node(world, entity, st, node.child)
                if result == bt.RUNNING then return bt.RUNNING end
                reset_subtree(st, node.child)
                return bt.SUCCESS
                
            elseif node.op == 'repeat' then
                state.count = state.count or 0
                local result = tick_node(world, entity, st, node.child)
                if result == bt.RUNNING then return bt.RUNNING end
                
                reset_subtree(st, node.child)
                state.count = state.count + 1
                
                if node.count and state.count >= node.count then
                    state.count = nil
                    return bt.SUCCESS
                else
                    return bt.RUNNING  -- Keep repeating
                end
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
        
        -- Tick the tree from current position
        tick_node(self.world, entity, st, st.tree.root)
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
            -- Reached target
            task_entity.task_complete = true
            task_entity.task_result = bt.SUCCESS
        else
            -- Move towards target
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
    reset_subtree(st, st.tree.root)
end

return bt