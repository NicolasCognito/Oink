# Behavior Trees in ECS: Implementation Guide

## Core Architecture Decisions

### 1. Store Logic in Systems, Not Data
```rust
// GOOD: Type-safe, compile-time checked
enum BehaviorAction {
    MoveTo { target: EntityId, speed: f32 },
    Attack { damage: f32, range: f32 },
    Wait { duration: Duration },
}

impl BehaviorSystem {
    fn execute(&mut self, action: &BehaviorAction, entity: Entity) -> NodeResult {
        match action {
            BehaviorAction::MoveTo { target, speed } => {
                // Actual logic here - debuggable, testable
            }
        }
    }
}

// BAD: Stringly-typed, runtime failures
struct DataNode {
    operation: String,  // "move_to" - typos compile fine!
    params: HashMap<String, Value>,
}
```

### 2. Tree Structure as Immutable Data, State as Mutable Component
```rust
// Tree definition - immutable, shareable
#[derive(Clone)]
struct BehaviorTree {
    nodes: Vec<BehaviorNode>,
    root: NodeId,
}

// Runtime state - mutable, per-entity
#[derive(Component)]
struct TreeExecutionState {
    current_node: NodeId,
    node_states: HashMap<NodeId, NodeState>,
    running_nodes: Vec<NodeId>,  // For parallel nodes
}

// This separation prevents state corruption and makes debugging easier
```

### 3. Tasks as Entities Pattern
```rust
// When a task starts, spawn an entity with task components
fn start_move_task(
    tree_entity: Entity,
    target: Entity,
    commands: &mut Commands,
) -> Entity {
    commands.spawn((
        MoveTask { 
            target,
            speed: 5.0,
        },
        TaskOwner(tree_entity),  // Links back to tree
        Name::new("Move to Target"), // Debug visibility
    )).id()
}

// System processes all active tasks
fn process_move_tasks(
    mut tasks: Query<(Entity, &MoveTask, &TaskOwner)>,
    mut transforms: Query<&mut Transform>,
    mut commands: Commands,
) {
    for (task_entity, task, owner) in tasks.iter() {
        // Do movement logic
        if arrived {
            // Report success and despawn
            commands.trigger(TaskComplete {
                tree: owner.0,
                result: NodeResult::Success,
            });
            commands.entity(task_entity).despawn();
        }
    }
}
```

## Implementation Patterns

### 1. Node Types with Explicit Requirements
```rust
trait BehaviorNode: Send + Sync {
    // Explicitly declare what components are needed
    type RequiredComponents: Bundle;
    
    // Validate before execution
    fn validate(&self, world: &World, entity: Entity) -> Result<(), NodeError>;
    
    // Execute with guaranteed components
    fn tick(&mut self, components: &Self::RequiredComponents) -> NodeResult;
}

// Example implementation
struct AttackNode {
    range: f32,
}

impl BehaviorNode for AttackNode {
    type RequiredComponents = (Transform, Combat, WeaponSlot);
    
    fn validate(&self, world: &World, entity: Entity) -> Result<(), NodeError> {
        world.get::<Combat>(entity)
            .ok_or(NodeError::MissingComponent("Combat"))?;
        // More validation...
        Ok(())
    }
}
```

### 2. Communication via Events/Triggers
```rust
// Define strongly-typed events
#[derive(Event)]
struct NodeCompleted {
    tree_entity: Entity,
    node_id: NodeId,
    result: NodeResult,
}

// Use Bevy's observer pattern for reactions
app.add_observer(on_node_completed);

fn on_node_completed(
    trigger: Trigger<NodeCompleted>,
    mut trees: Query<&mut TreeExecutionState>,
) {
    let event = trigger.event();
    if let Ok(mut state) = trees.get_mut(event.tree_entity) {
        state.advance_to_next_node(event.node_id, event.result);
    }
}
```

### 3. Parallel Node Execution
```rust
#[derive(Component)]
struct ParallelNodeState {
    child_tasks: Vec<Entity>,
    success_count: usize,
    failure_count: usize,
    required_successes: usize,
}

fn tick_parallel_node(
    entity: Entity,
    state: &mut ParallelNodeState,
    commands: &mut Commands,
) -> NodeResult {
    // Spawn all children as tasks
    if state.child_tasks.is_empty() {
        for child in children {
            let task = spawn_task(child, commands);
            state.child_tasks.push(task);
        }
        return NodeResult::Running;
    }
    
    // Check completion conditions
    if state.success_count >= state.required_successes {
        cleanup_remaining_tasks(&state.child_tasks, commands);
        return NodeResult::Success;
    }
    
    NodeResult::Running
}
```

## Common Pitfalls and Solutions

### 1. The Immediate Visibility Problem
```rust
// PROBLEM: Component changes aren't visible until next frame
fn bad_pattern(mut query: Query<&mut Status>) {
    for mut status in query.iter_mut() {
        status.value = StatusValue::Active;
    }
    // Another system in same frame won't see Active!
}

// SOLUTION 1: Use events for immediate communication
fn good_pattern_events(mut events: EventWriter<StatusChanged>) {
    events.send(StatusChanged::Active);
    // Observers can react immediately
}

// SOLUTION 2: Use explicit system ordering
app.add_systems(Update, (
    set_status_system,
    read_status_system,
).chain());  // Forces sequential execution
```

### 2. Resource Contention
```rust
// PROBLEM: Multiple nodes trying to control same component
struct MoveNode;
struct AttackNode;  
// Both try to set Velocity - conflict!

// SOLUTION: Action priority system
#[derive(Component)]
struct ActionController {
    current_action: Option<ActionType>,
    priority: i32,
}

fn request_action(
    entity: Entity,
    action: ActionType,
    priority: i32,
    controller: &mut ActionController,
) -> bool {
    if priority >= controller.priority {
        controller.current_action = Some(action);
        controller.priority = priority;
        true
    } else {
        false  // Lower priority, rejected
    }
}
```

### 3. Debugging Running Nodes
```rust
// Add debug components to track execution
#[derive(Component)]
struct BehaviorDebug {
    path: Vec<String>,  // Current execution path
    tick_count: u32,
    last_result: Option<NodeResult>,
    history: VecDeque<DebugEvent>,
}

// Debug visualization system
fn debug_behavior_trees(
    trees: Query<(&BehaviorDebug, &Name)>,
    mut gizmos: Gizmos,
) {
    for (debug, name) in trees.iter() {
        // Draw current node path
        let path_str = debug.path.join(" -> ");
        gizmos.text_2d(
            format!("{}: {}", name, path_str),
            Vec2::new(0.0, y_offset),
            Color::WHITE,
        );
    }
}
```

## Builder Pattern for Safe Tree Construction
```rust
pub struct BehaviorTreeBuilder {
    nodes: Vec<BehaviorNode>,
    current_parent: Option<NodeId>,
}

impl BehaviorTreeBuilder {
    pub fn sequence(mut self, f: impl FnOnce(&mut SequenceBuilder)) -> Self {
        let mut seq_builder = SequenceBuilder::new(&mut self.nodes);
        f(&mut seq_builder);
        seq_builder.finish();
        self
    }
    
    pub fn condition<T: ConditionNode>(mut self, condition: T) -> Self {
        self.validate_condition(&condition)?;
        self.nodes.push(BehaviorNode::Condition(Box::new(condition)));
        self
    }
    
    pub fn build(self) -> Result<BehaviorTree, BuildError> {
        self.validate_tree()?;
        Ok(BehaviorTree {
            nodes: self.nodes,
            root: NodeId(0),
        })
    }
    
    fn validate_tree(&self) -> Result<(), BuildError> {
        // Ensure no orphaned nodes
        // Ensure decorators have exactly one child
        // Ensure leaf nodes have no children
        Ok(())
    }
}
```

## Testing Strategies

### 1. Unit Test Individual Nodes
```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_attack_node_respects_range() {
        let mut world = World::new();
        
        // Setup test entities
        let attacker = world.spawn((
            Transform::from_xyz(0.0, 0.0, 0.0),
            Combat { damage: 10.0 },
        )).id();
        
        let target = world.spawn((
            Transform::from_xyz(100.0, 0.0, 0.0),
            Health { value: 100.0 },
        )).id();
        
        let mut node = AttackNode { range: 50.0, target };
        
        // Should fail - out of range
        assert_eq!(
            node.tick(&world, attacker),
            NodeResult::Failure(FailureReason::OutOfRange)
        );
    }
}
```

### 2. Integration Test Tree Execution
```rust
#[test]
fn test_complete_behavior_sequence() {
    let mut app = App::new();
    app.add_plugins(BehaviorTreePlugin);
    
    // Build test tree
    let tree = BehaviorTreeBuilder::new()
        .sequence(|s| {
            s.condition(HealthAbove(50.0))
             .action(MoveToTarget)
             .action(AttackTarget)
        })
        .build()
        .unwrap();
    
    // Spawn entity with tree
    let entity = app.world.spawn((
        BehaviorTreeBundle::new(tree),
        Transform::default(),
        Health { value: 75.0 },
    )).id();
    
    // Run until completion
    for _ in 0..100 {
        app.update();
        
        if let Some(state) = app.world.get::<TreeExecutionState>(entity) {
            if state.is_complete() {
                break;
            }
        }
    }
    
    // Verify end state
    let state = app.world.get::<TreeExecutionState>(entity).unwrap();
    assert_eq!(state.last_result(), Some(NodeResult::Success));
}
```

### 3. Property-Based Testing
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn tree_always_terminates(
        tree in arbitrary_tree(),
        max_ticks in 1..1000usize,
    ) {
        let result = execute_tree_with_limit(tree, max_ticks);
        // Tree should either complete or be running
        assert!(matches!(
            result,
            NodeResult::Success | 
            NodeResult::Failure(_) | 
            NodeResult::Running
        ));
    }
}
```

## Performance Tips (When You Eventually Care)

### 1. Cache Component Lookups
```rust
// Instead of querying every tick
fn slow_tick(&self, world: &World, entity: Entity) -> NodeResult {
    let transform = world.get::<Transform>(entity)?;
    let combat = world.get::<Combat>(entity)?;
    // Use components...
}

// Cache in node state
struct CachedNode {
    transform: Option<Entity>,
    combat: Option<Entity>,
}

fn fast_tick(&mut self, world: &World, entity: Entity) -> NodeResult {
    // Only lookup if invalidated
    if self.transform.is_none() {
        self.transform = Some(world.get::<Transform>(entity)?);
    }
    // Use cached components...
}
```

### 2. Pool Task Entities
```rust
#[derive(Resource)]
struct TaskPool {
    available: Vec<Entity>,
}

fn spawn_or_reuse_task(
    pool: &mut TaskPool,
    commands: &mut Commands,
) -> Entity {
    if let Some(entity) = pool.available.pop() {
        // Reuse existing entity
        commands.entity(entity)
            .insert(ActiveTask)
            .id()
    } else {
        // Spawn new
        commands.spawn(ActiveTask).id()
    }
}
```

## Best Practices Summary

1. **Make illegal states unrepresentable** - Use types to prevent invalid trees
2. **Fail fast and explicitly** - Validate early, return specific error types
3. **Keep trees pure data** - Logic in systems, configuration in trees
4. **Use events for coordination** - Avoid component mutation races
5. **Test at multiple levels** - Unit test nodes, integration test trees
6. **Add debug visibility** - Name entities, log paths, visualize execution
7. **Separate concerns** - Tree structure ≠ execution state ≠ blackboard data
8. **Embrace ECS patterns** - Tasks as entities, systems for logic
9. **Document node contracts** - What components needed, what side effects
10. **Version your trees** - Track changes for save game compatibility

## Example: Complete Mini Implementation

```rust
use bevy::prelude::*;

// Core types
#[derive(Component)]
pub struct BehaviorTree {
    root: NodeId,
    nodes: Vec<Node>,
}

#[derive(Component)]
pub struct TreeState {
    current: NodeId,
    history: Vec<(NodeId, NodeResult)>,
}

pub enum Node {
    Sequence { children: Vec<NodeId> },
    Selector { children: Vec<NodeId> },
    Action(Box<dyn ActionNode>),
}

pub trait ActionNode: Send + Sync {
    fn start(&self, entity: Entity, commands: &mut Commands) -> Entity;
}

// System to tick trees
fn tick_behavior_trees(
    mut trees: Query<(&BehaviorTree, &mut TreeState)>,
    tasks: Query<&TaskStatus>,
) {
    for (tree, mut state) in trees.iter_mut() {
        let node = &tree.nodes[state.current.0];
        
        match node {
            Node::Action(action) => {
                // Check if task completed
                if let Some(status) = check_task_status(&tasks) {
                    state.history.push((state.current, status));
                    state.advance();
                }
            }
            Node::Sequence { children } => {
                // Process sequence logic
            }
            Node::Selector { children } => {
                // Process selector logic
            }
        }
    }
}

pub struct BehaviorTreePlugin;

impl Plugin for BehaviorTreePlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(Update, tick_behavior_trees);
    }
}
```

This guide emphasizes correctness and maintainability over performance, following your priorities. The patterns shown here will help you build a robust, debuggable, and extensible behavior tree system.