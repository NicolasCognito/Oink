# Complete Guide: State Machines in Entity Component Systems

## Core Principle: Don't Fight ECS

**The Fundamental Rule**: All logic executes inside systems. Components are pure data. State machines are data structures that systems interpret.

## Quick Implementation Guide for tiny-ecs & LÖVE2D

### The Simplest Approach That Works

```lua
-- Just use a table in your entity
entity = {
    position = {x = 100, y = 200},
    velocity = {x = 0, y = 0},
    state = "idle",  -- Simple string/enum
    state_timer = 0,
    state_data = {}  -- Any state-specific data
}

-- Process in system
StateSystem.filter = tiny.requireAll("state", "position")
function StateSystem:process(entity, dt)
    entity.state_timer = entity.state_timer + dt
    
    -- Simple branching
    if entity.state == "idle" then
        -- Handle idle
        if self:canSeePlayer(entity) then
            entity.state = "chasing"
            entity.state_timer = 0
        end
    elseif entity.state == "chasing" then
        -- Handle chasing
    end
end
```

No special libraries needed. No complex abstractions. Just data and systems.

### Complete tiny-ecs Example

```lua
-- main.lua
local tiny = require("tiny")

-- Create a simple state system
local StateSystem = tiny.processingSystem()
StateSystem.filter = tiny.requireAll("state", "position")

function StateSystem:process(entity, dt)
    entity.state_timer = (entity.state_timer or 0) + dt
    
    -- Handle different entity types
    if entity.enemy_type == "zombie" then
        self:processZombie(entity, dt)
    elseif entity.enemy_type == "bat" then
        self:processBat(entity, dt)
    end
end

function StateSystem:processZombie(entity, dt)
    if entity.state == "idle" then
        if self:playerNearby(entity) then
            entity.state = "chasing"
            entity.state_timer = 0
            entity.animation = "run"
        end
    elseif entity.state == "chasing" then
        -- Move toward player
        local dx = self.player.position.x - entity.position.x
        entity.velocity.x = dx > 0 and 50 or -50
        
        if math.abs(dx) < 30 then
            entity.state = "attacking"
            entity.state_timer = 0
        end
    elseif entity.state == "attacking" then
        if entity.state_timer > 1.0 then  -- Attack duration
            entity.state = "idle"
            entity.state_timer = 0
        end
    end
end

function love.load()
    world = tiny.world()
    
    -- Create entities
    local zombie = {
        position = {x = 100, y = 300},
        velocity = {x = 0, y = 0},
        enemy_type = "zombie",
        state = "idle",
        state_timer = 0,
        animation = "idle"
    }
    
    local player = {
        position = {x = 400, y = 300},
        velocity = {x = 0, y = 0},
        player = true  -- Tag component
    }
    
    -- Add to world
    world:add(zombie, player)
    
    -- Add system with player reference
    local stateSystem = world:addSystem(StateSystem)
    stateSystem.player = player
end

function love.update(dt)
    world:update(dt)
end
```

### Scaling Up: Declarative State Definitions

```lua
-- states/zombie.lua - Define states as pure data
return {
    idle = {
        enter = function(entity, world)
            entity.velocity.x = 0
            entity.animation = "idle"
        end,
        
        update = function(entity, dt, world)
            entity.state_timer = entity.state_timer + dt
            
            if can_see_player(entity, world.player) then
                return "chasing"  -- Return next state
            elseif entity.state_timer > 2 then
                return "patrolling"
            end
        end
    },
    
    chasing = {
        enter = function(entity, world)
            entity.animation = "running"
        end,
        
        update = function(entity, dt, world)
            local dx = world.player.position.x - entity.position.x
            entity.velocity.x = dx > 0 and 60 or -60
            
            if math.abs(dx) < 30 then
                return "attacking"
            end
        end
    }
}

-- In your system
function StateSystem:process(entity, dt)
    local states = entity.state_def  -- Reference to state table
    local current = states[entity.state]
    
    if current and current.update then
        local next_state = current.update(entity, dt, self.world)
        
        if next_state and next_state ~= entity.state then
            -- Handle transition
            if current.exit then current.exit(entity, self.world) end
            entity.state = next_state
            entity.state_timer = 0
            if states[next_state].enter then 
                states[next_state].enter(entity, self.world)
            end
        end
    end
end

-- Creating an entity
local zombie = {
    position = {x = 100, y = 200},
    state = "idle",
    state_timer = 0,
    state_def = require("states.zombie")  -- Just reference the state table
}
```

## Why Traditional Approaches Fail

### The Tag-Based Approach (Don't Do This)
```cpp
// WRONG: Using tags/components to represent states
entity.add<WalkingState>();
entity.remove<IdleState>();
```

**Problems:**
- Causes constant archetype changes (terrible performance)
- Creates combinatorial explosion with multiple state machines
- Requires knowing current state to remove it
- Leads to hundreds of single-purpose systems

### The Component-Swapping Approach (Also Bad)
```cpp
// WRONG: Changing component composition for states
// Attack state = HasWeapon + HasTarget + IsAttacking
// Idle state = HasWeapon only
```

**Problems:**
- Maintenance nightmare with complex states
- Unclear state definitions
- Scattered transition logic
- Debugging hell

## The Solution: State Machine as Component

Store the FSM as data in a component. Systems read this data and execute behavior.

### Basic Implementation

```cpp
// SIMPLE AND EFFECTIVE
struct StateMachineComponent {
    StateID current_state;
    StateID previous_state;
    float time_in_state;
    std::unordered_map<std::string, std::any> blackboard;
};

// System checks state and acts accordingly
void CombatSystem::Update(float dt) {
    for (auto [entity, fsm, combat] : world->Query<StateMachineComponent, CombatData>()) {
        switch(fsm.current_state) {
            case STATE_IDLE:
                // Handle idle logic
                if (CanSeeEnemy(entity)) {
                    fsm.current_state = STATE_ATTACKING;
                    fsm.time_in_state = 0;
                }
                break;
                
            case STATE_ATTACKING:
                // Handle attack logic
                PerformAttack(entity, combat);
                if (AttackComplete(entity)) {
                    fsm.current_state = STATE_IDLE;
                }
                break;
        }
        
        fsm.time_in_state += dt;
    }
}
```

## Extensibility: The Real Trade-offs

### Where ECS State Machines WIN

**Adding orthogonal features across many entities:**
```lua
-- Normal OOP - modify every class
class Zombie 
    function update(dt)
        -- ADD burning logic here
        -- ADD freezing logic here  
        -- ADD poisoned logic here
    end
end

-- ECS - just add a new system
BurningSystem.filter = tiny.requireAll("burning", "health")
function BurningSystem:process(entity, dt)
    entity.health = entity.health - 5 * dt
    -- Works on ANY entity with "burning" component
end
```

**Runtime composition:**
```lua
-- Want a flying, poisonous, invisible zombie?
-- OOP: Need FlyingPoisonousInvisibleZombie class
-- ECS: Just add components
zombie.flying = {height = 50}
zombie.poisonous = {damage = 10}  
zombie.invisible = {duration = 5}
```

### Where ECS State Machines LOSE

**Complex interdependent state logic:**
```lua
-- Normal approach - clean and cohesive
function Enemy:update(dt)
    if self.state == "patrolling" then
        if self:seePlayer() and self:hasAmmo() then
            self.state = "attacking"
            self:alertNearbyAllies()
            self:takeCover()
        end
    end
end

-- ECS - logic scattered across systems
function StateSystem:process(entity, dt)
    if entity.state == "patrolling" then
        if entity.perception.sees_player and entity.weapon.ammo > 0 then
            entity.state = "attacking"
            entity.alert_request = true  -- Another system handles
            entity.cover_request = true  -- Another system handles
        end
    end
end
```

### When to Use Each Approach

**Use ECS State Machines when:**
- Many entities share similar behaviors
- You want runtime composition/modding
- You need data-driven content
- Performance from cache-friendly iteration matters
- Your game is about combining mechanics

**Use Normal Code when:**
- Few entities with unique complex behaviors  
- Deep, tightly coupled state logic
- Rapid prototyping/game jams
- Each entity is substantially different

### The Pragmatic Hybrid

```lua
-- Use ECS for broad strokes
entity.state = "attacking"
entity.health = 100

-- Delegate complex logic to normal code
local BossBehavior = require("behaviors.boss")
function StateSystem:process(entity, dt)
    if entity.complex_behavior then
        entity.complex_behavior:update(entity, dt)
    else
        -- Simple shared logic
        self:processGenericEnemy(entity, dt)
    end
end
```

## Complex State Machines

### Hierarchical States with Full Architecture

```cpp
// Complete state machine component for complex behaviors
struct StateMachineComponent {
    // Hierarchical state stack [Root, Parent, Current]
    std::vector<StateID> state_stack;
    
    // Parallel state machines
    struct ParallelFSM {
        StateID current;
        float timer;
        std::any state_data;
    };
    std::unordered_map<std::string, ParallelFSM> parallel_states;
    
    // Transition management
    std::queue<StateTransition> pending_transitions;
    int transitions_this_frame;  // Prevent infinite loops
    
    // State history for each composite state
    std::unordered_map<StateID, std::vector<StateID>> state_history;
    
    // Shared data between states
    std::unordered_map<std::string, std::any> blackboard;
    
    // Timing
    float time_in_current_state;
};

// State definitions stored as data
struct StateDefinition {
    StateID id;
    StateID parent;  // For hierarchy
    
    // Actions are just IDs that map to functions
    std::vector<ActionID> entry_actions;
    std::vector<ActionID> update_actions;
    std::vector<ActionID> exit_actions;
    
    // Transitions are data
    struct Transition {
        ConditionID condition;
        StateID target_state;
        uint8_t priority;
        bool is_interrupt;
    };
    std::vector<Transition> transitions;
    
    // Composite state support
    std::vector<StateID> children;
    StateID initial_child;
};
```

### The System That Runs Everything

```cpp
class StateMachineSystem {
    // All state definitions and logic mappings
    std::unordered_map<StateID, StateDefinition> state_definitions;
    std::unordered_map<ActionID, std::function<void(Entity, float)>> actions;
    std::unordered_map<ConditionID, std::function<bool(Entity)>> conditions;
    
public:
    void Update(float dt) {
        for (auto [entity, fsm] : world->Query<StateMachineComponent>()) {
            // Prevent infinite transitions
            fsm.transitions_this_frame = 0;
            
            // Update parallel state machines
            UpdateParallelStates(entity, fsm, dt);
            
            // Check for high-priority interrupts
            CheckInterrupts(entity, fsm);
            
            // Process any pending transitions
            ProcessTransitionQueue(entity, fsm);
            
            // Execute current state hierarchy
            UpdateStateHierarchy(entity, fsm, dt);
            
            // Check normal transitions
            CheckTransitions(entity, fsm);
            
            // Update timers
            fsm.time_in_current_state += dt;
        }
    }
    
private:
    void UpdateStateHierarchy(Entity e, StateMachineComponent& fsm, float dt) {
        // Execute from root to leaf
        for (StateID state_id : fsm.state_stack) {
            const auto& state = state_definitions[state_id];
            
            // Run update actions for this state level
            for (ActionID action : state.update_actions) {
                actions[action](e, dt);  // System executes stored logic
            }
        }
    }
    
    void ExecuteTransition(Entity e, StateMachineComponent& fsm, 
                          const StateTransition& transition) {
        // Find Least Common Ancestor
        StateID lca = FindLCA(transition.from, transition.to);
        
        // Exit states up to LCA
        StateID current = transition.from;
        while (current != lca) {
            const auto& state = state_definitions[current];
            
            // Save history
            if (state.parent != INVALID_STATE) {
                fsm.state_history[state.parent].push_back(current);
            }
            
            // Run exit actions
            for (ActionID action : state.exit_actions) {
                actions[action](e, 0);
            }
            
            current = state.parent;
        }
        
        // Enter states down to target
        std::vector<StateID> path = BuildPath(lca, transition.to);
        for (StateID state_id : path) {
            const auto& state = state_definitions[state_id];
            
            // Run entry actions
            for (ActionID action : state.entry_actions) {
                actions[action](e, 0);
            }
        }
        
        // Update state stack
        RebuildStateStack(fsm, transition.to);
        fsm.time_in_current_state = 0;
    }
};
```

## Logic as Data Pattern

The most powerful pattern: **Store functions as data, execute them in systems**.

### Basic Logic-as-Data

```cpp
struct StateMachineComponent {
    // Functions stored as component data
    std::function<bool(Entity)> current_condition;
    std::function<void(Entity, float)> current_action;
    std::function<StateID(Entity)> transition_evaluator;
};

// System executes the stored functions
void StateMachineSystem::Update(float dt) {
    for (auto [entity, fsm] : world->Query<StateMachineComponent>()) {
        // System EXECUTES stored logic
        if (fsm.current_condition && fsm.current_condition(entity)) {
            fsm.current_action(entity, dt);  // Executing stored function
            
            StateID next = fsm.transition_evaluator(entity);
            if (next != fsm.current_state) {
                TransitionTo(entity, fsm, next);
            }
        }
    }
}
```

### Complete State with Embedded Logic

```cpp
struct State {
    std::string name;
    
    // Logic stored as data
    std::function<void(Entity)> on_enter;
    std::function<void(Entity, float)> on_update;
    std::function<void(Entity)> on_exit;
    
    // Transition logic also as data
    struct Transition {
        std::function<bool(Entity)> condition;
        StateID target;
        int priority;
    };
    std::vector<Transition> transitions;
};

// Building states with logic
State CreatePatrolState() {
    return State{
        .name = "Patrol",
        
        .on_enter = [](Entity e) {
            e.get<Animation>().Play("walk");
            e.get<Movement>().speed = 2.0f;
        },
        
        .on_update = [](Entity e, float dt) {
            auto& patrol = e.get<PatrolData>();
            auto& transform = e.get<Transform>();
            
            Vector3 target = patrol.waypoints[patrol.current];
            Vector3 direction = normalize(target - transform.position);
            e.get<Movement>().velocity = direction * 2.0f;
            
            if (distance(transform.position, target) < 1.0f) {
                patrol.current = (patrol.current + 1) % patrol.waypoints.size();
            }
        },
        
        .on_exit = [](Entity e) {
            e.get<Movement>().velocity = Vector3::ZERO;
        },
        
        .transitions = {
            {
                .condition = [](Entity e) {
                    return e.get<Perception>().can_see_player;
                },
                .target = STATE_CHASE,
                .priority = 10
            },
            {
                .condition = [](Entity e) {
                    auto& health = e.get<Health>();
                    return health.current < health.max * 0.3f;
                },
                .target = STATE_FLEE,
                .priority = 20
            }
        }
    };
}
```

### System Executes All Logic

```cpp
class StateMachineSystem {
    void Update(float dt) {
        for (auto [entity, fsm] : world->Query<StateMachineComponent>()) {
            State& current = fsm.states[fsm.current_state];
            
            // SYSTEM executes stored update logic
            if (current.on_update) {
                current.on_update(entity, dt);
            }
            
            // SYSTEM evaluates stored conditions
            for (const auto& transition : current.transitions) {
                if (transition.condition(entity)) {
                    ExecuteTransition(entity, fsm, transition.target);
                    break;
                }
            }
        }
    }
    
    void ExecuteTransition(Entity e, StateMachineComponent& fsm, StateID target) {
        State& from = fsm.states[fsm.current_state];
        State& to = fsm.states[target];
        
        // SYSTEM executes stored exit logic
        if (from.on_exit) {
            from.on_exit(e);
        }
        
        fsm.current_state = target;
        fsm.time_in_state = 0;
        
        // SYSTEM executes stored enter logic
        if (to.on_enter) {
            to.on_enter(e);
        }
    }
};
```

## Parallel State Machines

Run multiple FSMs simultaneously on the same entity:

```cpp
void UpdateParallelStates(Entity e, StateMachineComponent& fsm, float dt) {
    // Each parallel FSM updates independently
    for (auto& [name, parallel_fsm] : fsm.parallel_states) {
        if (name == "movement") {
            UpdateMovementFSM(e, parallel_fsm, dt);
        } else if (name == "animation") {
            UpdateAnimationFSM(e, parallel_fsm, dt);
        } else if (name == "combat") {
            UpdateCombatFSM(e, parallel_fsm, dt);
        }
        
        parallel_fsm.timer += dt;
    }
}

// Example: Boss with multiple parallel behaviors
void CreateBoss(Entity boss) {
    auto& fsm = boss.add<StateMachineComponent>();
    
    // Main behavior FSM
    fsm.state_stack = {STATE_COMBAT, STATE_PHASE1, STATE_ATTACKING};
    
    // Parallel FSMs
    fsm.parallel_states["movement"] = {STATE_CIRCLING, 0, CircleData{radius: 10}};
    fsm.parallel_states["abilities"] = {STATE_COOLDOWN, 0, AbilityData{}};
    fsm.parallel_states["animation"] = {STATE_COMBAT_IDLE, 0, {}};
}
```

## Interrupt System

Handle high-priority state changes:

```cpp
void CheckInterrupts(Entity e, StateMachineComponent& fsm) {
    static const std::vector<InterruptDef> interrupts = {
        {CONDITION_TAKING_DAMAGE, STATE_DAMAGED, priority: 100},
        {CONDITION_LOW_HEALTH, STATE_FLEEING, priority: 75},
        {CONDITION_PLAYER_CLOSE, STATE_ALERT, priority: 50},
    };
    
    for (const auto& interrupt : interrupts) {
        if (conditions[interrupt.condition](e)) {
            uint8_t current_priority = GetStatePriority(fsm.current_state);
            
            if (interrupt.priority > current_priority) {
                // Force immediate transition
                fsm.pending_transitions = {};  // Clear queue
                fsm.pending_transitions.push({fsm.current_state, interrupt.state});
                break;
            }
        }
    }
}
```

## Behavior Trees as Data

Same pattern applies to behavior trees:

```cpp
struct BehaviorNode {
    std::function<NodeStatus(Entity, float)> execute;
    std::vector<std::unique_ptr<BehaviorNode>> children;
};

// Create behavior tree
auto CreateAITree() {
    auto root = std::make_unique<BehaviorNode>();
    
    // Selector node
    root->execute = [](Entity e, float dt) {
        for (auto& child : children) {
            auto status = child->execute(e, dt);
            if (status != FAILURE) return status;
        }
        return FAILURE;
    };
    
    // Add child behaviors
    root->children.push_back(CreateAttackBehavior());
    root->children.push_back(CreateFleeBehavior());
    root->children.push_back(CreatePatrolBehavior());
    
    return root;
}

// System executes the tree
void BehaviorTreeSystem::Update(float dt) {
    for (auto [entity, tree] : world->Query<BehaviorTreeComponent>()) {
        tree.root->execute(entity, dt);  // System executes stored logic
    }
}
```

## Script Integration

Load behaviors from scripts:

```cpp
// Lua integration
class ScriptedStateMachine {
    static void LoadFromLua(StateMachineComponent& fsm, const std::string& file) {
        lua_State* L = luaL_newstate();
        luaL_dofile(L, file.c_str());
        
        // Wrap Lua functions as C++ lambdas
        fsm.states[STATE_PATROL].on_update = [L](Entity e, float dt) {
            lua_getglobal(L, "patrol_update");
            PushEntity(L, e);
            lua_pushnumber(L, dt);
            lua_call(L, 2, 0);
        };
    }
};
```

## Key Insights Summary

### 1. **Components Are Pure Data**
Never put update methods or state-changing logic in components. Components are just containers. Even function pointers stored in components are just data - they're executed by systems.

### 2. **Systems Execute All Logic**
Every piece of behavior runs inside a system's Update method. No exceptions. When functions are stored as component data, systems still execute them.

### 3. **State Machines Are Data Structures**
The FSM is just a data structure that systems interpret. It's not an active object. Don't wrap it in unnecessary OOP abstractions.

### 4. **Start Simple, Add Complexity As Needed**
A state field with a string/enum and a switch statement in your system is often enough. Don't over-engineer until you need it.

### 5. **Don't Represent Control Flow as Component Layout**
States aren't tags. Transitions aren't component changes. Keep your archetypes stable. The tag-based approach is the main anti-pattern to avoid.

### 6. **ECS Isn't Always The Answer**
ECS makes some problems easier and others harder. Use it for shared behaviors and data-driven content. Use normal code for complex unique logic. Hybrid approaches are fine.

### 7. **Declarative > Imperative in ECS**
Define states as data tables with functions, not as classes with methods. Let systems be the interpreters of this declarative data.

## Benefits of This Approach

- **Performance**: No archetype changes, cache-friendly iteration
- **Debuggable**: See entire state machine state in debugger
- **Data-Driven**: Load from files, modify at runtime
- **Testable**: Mock behaviors easily
- **Composable**: Mix and match behaviors
- **Maintainable**: Logic is centralized in systems
- **Scalable**: Add complexity without architectural changes

## Common Pitfalls to Avoid

1. **Don't use tags for states** - This is the #1 mistake and what Sander Mertens' article warns against
2. **Don't overthink it** - Start with a simple enum/string and a switch statement
3. **Don't create a system per state** - Use one system that handles all states
4. **Don't wrap everything in classes** - In ECS, prefer data tables over OOP abstractions
5. **Don't be a purist** - Mix ECS and normal code where it makes sense
6. **Don't make components smart** - Keep them as pure data containers
7. **Don't fight the architecture** - If something feels really hard in ECS, consider if it should be done differently

## Conclusion

State machines in ECS work best when you treat them as data structures that systems interpret. The key insight from the community and practice is: **don't try to make the ECS architecture itself represent your state machine** (no tags as states, no component swapping for transitions).

Instead:
1. Store state as simple data (enum/string) in a component
2. Let systems process that data with straightforward branching
3. Use declarative state definitions for complex cases
4. Don't be afraid to mix approaches - use ECS where it helps, normal code where it doesn't

The pursuit of "pure ECS" is academic. Real games use pragmatic solutions. Your state machine doesn't need to be clever - it needs to be debuggable, extensible in the ways YOUR game needs, and easy for your team to understand.

The best state machine is the one that ships your game.