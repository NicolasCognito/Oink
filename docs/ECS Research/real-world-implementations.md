# ECS Behavior Trees: Real-World Implementation Patterns

**EntitiesBT and bevy_behave represent the most mature ECS behavior tree implementations**, demonstrating a fundamental shift from traditional blackboard-based data sharing to component-centric architectures. These systems achieve significant performance improvements through data-oriented design while maintaining behavior tree flexibility.

Modern ECS behavior tree implementations **abandon traditional blackboards in favor of direct component access**, leveraging ECS query systems for type-safe, high-performance data sharing. The most successful implementations use continuous memory layouts and zero-allocation execution patterns, enabling thousands of concurrent AI entities.

## Real-world implementations dominate Unity DOTS and Bevy ecosystems

**Unity DOTS leads in maturity and production readiness**. EntitiesBT stands out as the most comprehensive implementation, featuring data-oriented design with continuous BlobData structures, zero GC allocation during execution (only 64 bytes per tick), and thread control with flexible execution contexts. The framework demonstrates **sophisticated ECS integration** through automatic EntityQuery generation based on component access patterns.

```csharp
[BehaviorNode("F5C2EE7E-690A-4B5C-9489-FB362C949192")]
public struct EntityMoveNode : INodeData {
    public float3 Velocity;
    public NodeState Tick<TNodeBlob, TBlackboard>(int index, ref TNodeBlob blob, ref TBlackboard bb) {
        ref var translation = ref bb.GetDataRef<Translation>(); // Direct component access
        var deltaTime = bb.GetData<BehaviorTreeTickDeltaTime>();
        translation.Value += Velocity * deltaTime.Value;
        return NodeState.Running;
    }
}
```

**Bevy's ecosystem shows rapid innovation** with bevy_behave introducing a novel entity-spawning approach. When behavior tree nodes execute, they spawn temporary entities with task components, leveraging Bevy's observer pattern for status reporting. This design achieves remarkable performance, handling 100k+ entities in stress tests while maintaining clean ECS principles.

```rust
let tree = behave! {
    Behave::Forever => {
        Behave::Sequence => {
            Behave::spawn((
                Name::new("Move towards player"),
                MoveTowardsPlayer{player, speed: 100.0}
            )),
            Behave::trigger(RandomizeColour),
            Behave::Wait(5.0),
        }
    }
};
```

**DOTS-BehaviorTree** by SinyavtsevIlya represents another Unity approach, emphasizing **100% ECS focus with "no blackboards, no unrelated systems"**. It pairs components with corresponding systems, where each behavior component has a dedicated system handling the logic.

## Components completely replace traditional blackboards

The research reveals a **fundamental architectural shift**: ECS behavior trees largely abandon separate blackboard data structures in favor of direct component access patterns. **The ECS component system itself serves as the blackboard**, providing type-safe, high-performance data sharing that traditional blackboards offered.

**EntitiesBT exemplifies this approach** through its variant system supporting multiple data source patterns:
- **LocalVariant**: Node-local data in blob structures  
- **ComponentVariant**: Direct component access with optional caching
- **NodeVariant**: Cross-node data sharing within behavior trees
- **ScriptableObjectVariant**: External data source integration

```csharp
// Automatic query generation from component access patterns
[ReadOnly(typeof(ReadOnlyComponent))]
[ReadWrite(typeof(ReadWriteComponent))]
public NodeState Tick<TNodeBlob, TBlackboard>(int index, ref TNodeBlob blob, ref TBlackboard blackboard) {
    bb.GetData<ReadOnlyComponent>();     // Generates ReadOnly access
    bb.GetDataRef<ReadWriteComponent>(); // Generates ReadWrite access
}
```

**Bevy implementations demonstrate pure component-based storage**. The bevy_behave framework spawns entities with behavior components, while bevior_tree integrates directly with Bevy's component system. Both approaches eliminate traditional blackboards entirely, instead leveraging ECS queries for data access.

## Per-entity blackboards give way to component queries

**Traditional per-entity blackboards are obsolete** in modern ECS behavior tree implementations. Instead, systems use **entity-specific component queries** to access required data. This pattern provides superior performance through cache-friendly memory layouts and enables parallel processing of multiple AI entities.

**Memory organization patterns** show sophisticated optimization:
- **Blob-based storage**: EntitiesBT stores all behavior tree data in continuous memory blobs for cache efficiency
- **Flyweight pattern**: Separation of stateless tree structure from per-entity state enables memory sharing
- **Depth-first organization**: Tree structure and data flattened into arrays ordered for linear access patterns

The **stateless design principle** dominates successful implementations. Behavior tree nodes contain no instance data, with all state stored separately in components or blob structures. This enables lockless multithreading and shared tree structures across multiple entities.

## Code examples reveal sophisticated ECS patterns

**System-component pairing** represents a key architectural pattern. DOTS-BehaviorTree demonstrates this approach where each behavior component has a corresponding system:

```csharp
[GenerateAuthoringComponent]
public struct SeekEnemy : IComponentData { }

public sealed class BTSeekEnemySystem : SystemBase {
    protected override void OnUpdate() {
        Entities.WithAll<SeekEnemy>()
            .ForEach((Entity agentEntity, in BTActionNodeLink bTNodeLink) => {
                beginSimECB.AddComponent(bTNodeLink.Value, BTResult.Success);
            }).ScheduleParallel();
    }
}
```

**Bevy's component-based task implementation** shows elegant integration with ECS systems:

```rust
#[derive(Component, Clone, Default)]
struct WingFlapper { speed: f32 }

fn wing_flap_system(
    mut q_target: Query<&mut Wings, With<BirdMarker>>,
    flapper_tasks: Query<(&WingFlapper, &BehaveCtx)>,
    mut commands: Commands
) {
    for (flapper, ctx) in flapper_tasks.iter() {
        let target = ctx.target_entity();
        let Ok(mut target_wings) = q_target.get_mut(target) else {
            commands.trigger(ctx.failure());
            continue;
        };
        target_wings.flap(flapper.speed);
    }
}
```

## Key architectural differences from OOP behavior trees

**Memory layout transformation** represents the most significant difference. OOP behavior trees scatter data across heap-allocated objects, creating cache misses and garbage collection pressure. ECS implementations organize data in **contiguous component arrays**, enabling better cache locality and elimination of runtime allocations.

**Execution model changes** show fundamental paradigm shifts:
- **OOP**: Virtual function calls traverse tree nodes with scattered memory access
- **ECS**: System queries process similar components together with linear memory access
- **Parallelization**: ECS enables natural parallel processing versus manual synchronization in OOP

**Data access patterns** reveal architectural evolution:
- **OOP**: Behavior trees access external blackboards through key-value lookups
- **ECS**: Direct component access through type-safe query systems
- **Performance**: Component access leverages ECS caching versus hash table lookups

**Extensibility approaches** demonstrate different design philosophies:
- **OOP**: Inheritance-based node types with virtual method overrides
- **ECS**: Composition-based with components and corresponding systems
- **Type Safety**: ECS provides compile-time component access validation

## Rust implementations lead innovation patterns

**Bevy's ecosystem demonstrates cutting-edge approaches** with multiple competing implementations exploring different architectural patterns. The bevy_behave framework introduces **dynamic entity spawning** as a novel execution strategy, while bevior_tree follows more traditional component-based approaches.

**Performance characteristics** show Rust implementations achieving exceptional scalability. The bevy_behave framework handles 100k+ entities in stress tests, demonstrating that Rust's memory safety and ECS optimization can achieve remarkable AI entity counts without performance degradation.

**Framework-agnostic libraries** like bonsai-bt and behavior-tree provide general-purpose implementations that can integrate with any ECS, though they require manual integration work compared to framework-specific solutions.

## Conclusion

ECS behavior tree implementations represent a **mature evolution beyond traditional OOP approaches**, offering significant performance advantages through data-oriented design principles. The most successful implementations completely replace blackboards with component-based data access, achieving zero-allocation execution and enabling massive AI entity counts.

**EntitiesBT in Unity DOTS and bevy_behave in Rust** emerge as the leading implementations, each demonstrating sophisticated approaches to integrating behavior trees with ECS paradigms. These frameworks prove that behavior tree flexibility can coexist with ECS performance optimization, creating AI systems capable of handling thousands of concurrent entities while maintaining clean architectural patterns.