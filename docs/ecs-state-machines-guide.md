# Complete Guide: State Machines in Entity Component Systems

## Core Principle: Don't Fight ECS

**The Fundamental Rule**: All logic executes inside systems. Components are pure data. State machines are data structures that systems interpret.

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
Never put update methods or state-changing logic in components. Components are just containers.

### 2. **Systems Execute All Logic**
Every piece of behavior runs inside a system's Update method. No exceptions.

### 3. **State Machines Are Data Structures**
The FSM is just a data structure that systems interpret. It's not an active object.

### 4. **Functions Can Be Data**
Store lambdas/function objects in components. Systems execute them. This enables data-driven behavior while respecting ECS principles.

### 5. **Don't Represent Control Flow as Component Layout**
States aren't tags. Transitions aren't component changes. Keep your archetypes stable.

### 6. **Parallel and Hierarchical States Are Just More Data**
Complex state patterns are just more sophisticated data structures for systems to interpret.

## Benefits of This Approach

- **Performance**: No archetype changes, cache-friendly iteration
- **Debuggable**: See entire state machine state in debugger
- **Data-Driven**: Load from files, modify at runtime
- **Testable**: Mock behaviors easily
- **Composable**: Mix and match behaviors
- **Maintainable**: Logic is centralized in systems
- **Scalable**: Add complexity without architectural changes

## Common Pitfalls to Avoid

1. **Don't create a system per state** - Use one system that handles all states
2. **Don't use tags for states** - Store state as an enum/ID in a component
3. **Don't scatter transition logic** - Centralize it in the state machine system
4. **Don't make components smart** - Keep them as pure data containers
5. **Don't fight the ECS paradigm** - Embrace data-oriented design

## Conclusion

State machines in ECS work best when you treat them as data structures that systems interpret. Store the state graph, conditions, and actions as data. Let systems execute that data. This approach gives you all the benefits of state machines while maintaining the performance and architectural benefits of ECS.