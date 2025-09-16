Behavior Trees in Entity-Component Systems: Patterns and Best Practices

Executive Summary

Behavior Trees (BTs) are a powerful AI pattern for game agents, and
integrating them with Entity-Component Systems (ECS) requires careful
design to remain efficient and scalable. This guide explores how to
represent and execute BTs in a **framework-agnostic ECS** context,
drawing on proven patterns from Unity DOTS (C#), Bevy (Rust), Flecs (C),
EnTT (C++), and Unreal Mass (C++). We cover how to map BT data
structures to ECS data, different execution models (from straightforward
per-entity ticks to event-driven task spawning), management of state and
memory (to avoid allocations and maintain cache locality), safe data
access (reading/writing components through blackboards or command
buffers), authoring approaches (code vs data, tooling for
visualization/debugging), performance techniques for scaling to
thousands of agents (e.g. selective ticking and parallel jobs), and
testing strategies for deterministic behavior. The goal is to generalize
*vendor-neutral best practices* so you can implement BTs on any ECS
without tying to a specific engine, while noting ecosystem-specific
adaptations where relevant.

**Key takeaways:**

- *Behavior Tree Representation:* You can represent BTs as *data
  > assets/graphs* (e.g. blob or JSON structures) or hardcoded logic.
  > Data-driven BTs allow designers to author trees visually and
  > serialize them, while code-driven BTs can leverage compile-time
  > optimizations. In ECS, a common approach is to store the tree
  > definition in a *shared asset* and have each agent entity hold a
  > component referencing that tree plus any per-instance state (like
  > node execution status or local variables).

- *ECS Integration Patterns:* A BT can run as a system that ticks all
  > entities with BT components each frame, or you can adopt an
  > **event-driven model** where BT logic spawns ECS *tasks* that run
  > asynchronously. For example, a BT action node could **spawn an
  > entity with specific components** to perform a long-running action
  > (like moving or waiting) and signal back when
  > done[[\[1\]]{.underline} HYPERLINK
  > \"https://www.hankruiger.com/posts/bevy-behave/#:\~:text=An%20important%20difference%20between%20Bevy,you%20want%20it%20to%20control\"[\[2\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned).
  > This decoupling fits ECS: systems handle the *task components* in
  > bulk, and the BT resumes when tasks report success or failure via
  > events.

- *State Management and Performance:* Successful ECS BT implementations
  > avoid runtime allocations and heavy virtual calls. Instead, they
  > often use contiguous memory for tree data and *preallocate node
  > state* for each entity. For instance, Unity DOTS approaches like
  > EntitiesBT store all nodes in a **continuous memory blob** and
  > maintain an array of node states per tree
  > instance[[\[3\]]{.underline} HYPERLINK
  > \"https://github.com/quabug/EntitiesBT#:\~:text=match%20at%20L715%20public%20BlobArray,once%20reset\"[\[4\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,with%20Unity%20GameObject%20without%20entity).
  > This yields **allocation-free ticks** and better cache
  > locality[[\[5\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync).
  > Nodes carry no internal heap pointers; all context comes from
  > components (blackboard data) or indices, making it easy to reset or
  > serialize state.

- *Data Access & Safety:* In ECS, behavior nodes must interact with
  > component data in a way that doesn\'t thrash the cache or violate
  > safety in multithreading. A typical solution is to use a
  > *Blackboard* -- a structured access to components. For example, a
  > movement node might get a reference to the entity's Translation
  > component via the blackboard and update
  > it[[\[6\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,Running%3B).
  > When running in jobs, writes are often deferred: e.g. using command
  > buffers or special write-back variants to avoid race
  > conditions[[\[7\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,NodeData).
  > Some frameworks introduce explicit controls; in EntitiesBT, a node
  > can be marked to **run on the main thread** if it needs to call
  > non-threadsafe
  > APIs[[\[8\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,once%20meet%20decorator%20of%20RunOnMainThread).
  > Best practice is to batch expensive queries outside individual ticks
  > (e.g. a sensor system tags entities seen by an enemy, rather than
  > each BT doing its own raycast) and let BT nodes simply read those
  > results.

- *Authoring & Debugging:* BTs can be authored through code (with
  > DSL-like fluent APIs or template metaprogramming) or via data
  > (visual editors producing an asset). In Unity and Unreal, visual
  > editors are common, and even ECS-centric solutions keep that
  > workflow by baking graphs into data at build
  > time[[\[9\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,suspended).
  > Code-driven BTs (like some Rust/EnTT patterns) sacrifice hot-reload
  > but can be more type-safe and high-performance by eliminating
  > dynamic dispatch. Hybrid approaches use code for custom actions but
  > data/graphs for overall tree structure -- this gives designers
  > control without sacrificing optimization. **Debugging tools** are
  > crucial: ECS BT frameworks often include real-time visualization of
  > each agent's tree and node
  > statuses[[\[10\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync),
  > step-through execution controls, and logging of transitions.
  > Telemetry such as which node failed last or how often a branch is
  > taken can be recorded in components (counters, timestamps, "reason
  > codes") to tune AI behaviors.

- *Performance & Scaling:* To scale BT-driven AI to hundreds or
  > thousands of entities, use ECS strengths: **chunking and
  > parallelism.** Organize AI updates into phase-based systems (e.g.
  > sensing, decision, acting) and update at variable frequencies if
  > possible (e.g. far-away NPCs tick at lower rate or use simpler
  > logic). Many ECS BT designs support *partial updates* or
  > event-driven updates to avoid useless work. For instance, instead of
  > traversing an entire tree every frame, a conditional can "sleep"
  > until relevant changes occur (Unity's Behavior Designer uses
  > **Conditional Aborts** to only re-evaluate parts of the tree on
  > state
  > changes[[\[11\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=With%20traditional%20behavior%20tree%20implementations,executed%20if%20the%20status%20changes)).
  > In ECS terms, this could be achieved by systems that add a "wakeup"
  > component or event to an entity when a blackboard value changes,
  > triggering the BT system to run for that entity. Also consider using
  > LOD: a high-detail BT for nearby agents and a cheaper AI for distant
  > ones, switching components as needed. **Parallelize** BT evaluations
  > by leveraging jobs/task systems -- e.g. schedule BT ticks in
  > parallel over chunks of entities (Unity's DOTS can do this easily,
  > and other ECS frameworks can spawn worker threads). The heavy
  > lifting inside leaf nodes (like pathfinding) can also be offloaded
  > to jobs or vectorized operations. With these techniques, modern ECS
  > BT solutions have been shown to handle even tens of thousands of
  > agents -- for example, the developer of a popular Unity BT asset
  > noted testing "agents numbering in the tens or hundreds of
  > thousands" with a DOTS-based BT
  > system[[\[12\]]{.underline}](http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/#:~:text=Awesome%2C%20and%20thanks%20for%20sharing,a%20lot%20cleaner%20Image%3A).

- *Testing & Determinism:* ECS makes it feasible to run bulk AI
  > simulations for testing. Create deterministic test scenarios (e.g.
  > fixed random seeds and controlled environment components) to
  > validate BT logic. It's wise to implement **deterministic timers and
  > random generators** -- for example, use a fixed-step game time or a
  > noise-based RNG per entity so that BT decisions can be reproduced
  > exactly in replays or multiplayer
  > lockstep[[\[13\]]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/#:~:text=forward%20efficiently%2C%20and%20may%20have,compelling%20option%20for%20game%20devs).
  > Write unit tests for individual node logic (especially action and
  > condition nodes) by feeding them synthetic blackboard data.
  > Property-based testing can randomize blackboard values to ensure the
  > BT handles all cases without stuck "Running" states or invalid
  > transitions. For long-running behaviors, consider **scenario
  > harnesses**: small ECS worlds with one or few agents where you
  > simulate their BT over time and assert expected outcomes (a "golden
  > path" test). Logging each decision tick with timestamps (or using
  > ECS event tracing) can help compare against expected traces.
  > Finally, keep the BT logic *pure* (where possible) -- i.e. separate
  > decision-making from direct side-effects -- to make it easier to
  > rollback or replay in deterministic simulations. If
  > rollback/prediction (for multiplayer) is needed, ensure the BT's
  > state (node statuses, etc.) is part of the replicated state or can
  > be recomputed solely from deterministic inputs each tick.

Following sections delve deeper into each aspect, with comparisons of
alternative approaches and concrete best practices (summarized in a
checklist and decision matrix at the end). By understanding these
patterns, you can implement robust and scalable behavior trees atop any
ECS framework.

Mapping Behavior Trees to ECS Data Structures

*Editor\'s note: In ECS, 'blackboard' means a typed accessor over ECS
components; do not maintain a separate per-entity key-value store*

**Tree as Data vs. Code:** In an ECS, you typically cannot rely on
standard OOP inheritance for behavior nodes -- instead, you either
encode the tree in data or in a structured code form. A **data-driven
BT** represents the behavior tree as an asset or set of components (e.g.
a scriptable object, JSON, or Blob asset) that defines nodes and their
relationships. Each entity (agent) then has a component referencing this
BT asset plus whatever runtime state it needs. This approach was used by
Unity DOTS-based solutions like *EntitiesBT*, which builds the tree into
a **BlobAsset** containing all node definitions and a default state
snapshot[[\[3\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,with%20Unity%20GameObject%20without%20entity).
The BlobAsset can be shared among many entities of the same type,
improving memory usage. Data-driven trees shine for designer workflow
(visual editors, live tuning) and allow dynamic loading or swapping of
behaviors at runtime (e.g. different BT assets for different NPC types).
The downside is some overhead in interpreting the data and less
compile-time checking -- you need to ensure the data is kept in sync
with code (usually via node ID mappings or reflection).

In contrast, a **code-driven BT** might use templated or hardcoded logic
to represent the tree structure. For example, a C++ implementation could
compose node types with templates and function calls, ending up with one
big compiled function/object for the entire
tree[[\[14\]]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html#:~:text=,inline%2C%20and%20do%20other%20magic).
This yields *extremely optimized, cache-friendly code* -- the whole tree
is inlined, no pointers between nodes, and no runtime polymorphism, as
described by Lisyarus for a C++ BT library (the "entire tree is a single
enormous object" in memory, maximizing locality and letting the compiler
fully
optimize)[[\[15\]]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html#:~:text=Amusingly%2C%20it%20actually%20works%21%20The,benefits%20of%20this%20approach%20are).
The clear trade-off is flexibility: changing the tree means recompiling
code; you can't easily author it in a visual tool or data file. In
practice, many ECS implementations lean toward *hybrid approaches*: e.g.
core logic in code (for speed and safety) but tree structure in data.
Unity's DOTS BT solutions used codegen to bridge this gap -- EntitiesBT
auto-generates entity query functions for nodes and uses attributes to
register node types by GUID[[\[16\]]{.underline} HYPERLINK
\"https://github.com/quabug/EntitiesBT#:\~:text=%5BBehaviorNode%28%22867BFC14,float%3E%20FloatVariant\"[\[17\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=Packages),
so at runtime the blob data can invoke the correct code without virtual
calls.

**Component Schema:** However you represent the tree, you will need a
set of ECS components to hold BT-related state on each agent. A typical
schema might include:

- **BehaviorTree or BTAgent component:** identifies that an entity has a
  > BT, and often holds a reference (asset ID or pointer) to the tree
  > data/asset. It may also contain an index or pointer to the root node
  > in that data. In some designs it also holds a *current node index*
  > if the tree isn't always executed from root.

- **Node State storage:** If nodes can be in a running state, you need
  > to track that per entity. One way is a component that contains an
  > array of node statuses (indexed by node ID) for the tree. For
  > example, EntitiesBT's blob for each tree included a
  > BlobArray\<NodeState\> States for the runtime status of each
  > node[[\[4\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=match%20at%20L715%20public%20BlobArray,once%20reset).
  > This array can be allocated when the entity is initialized with the
  > BT (or stored in a separate dynamic buffer component in ECS). Some
  > implementations avoid even this, by encoding state into components
  > themselves or by designing nodes to be stateless (more on that
  > below).

- **Blackboard component(s):** The blackboard is the memory of the BT --
  > a set of variables that nodes read/write. In ECS, there's an
  > opportunity to directly use *components as the blackboard*. That is,
  > instead of storing variables in a separate object, you treat certain
  > components on the entity (or related entities) as the blackboard
  > data. This is exactly what EntitiesBT does: the TBlackboard in its
  > generic tick function is essentially an ECS data context that allows
  > nodes to get component values by
  > type[[\[6\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,Running%3B).
  > For instance, if an agent entity has a Health component, a BT
  > condition node "IsHealthLow" can simply read from that. In Bevy
  > Behave, the blackboard might be more implicit -- since the BT tasks
  > spawn separate entities, those tasks use components on themselves or
  > on the agent to decide things (e.g. a task might read the agent's
  > Hunger component to decide success). If a shared blackboard (across
  > multiple agents) is needed (e.g. squad-level info), that can be an
  > ECS entity that all agents refer to via an ID or a component
  > containing a reference.

- **Execution context components:** Some frameworks add a small
  > component to manage BT execution per entity, for example storing the
  > current running node pointer or a timestamp for next tick. Bevy's
  > BehaveTree component internally holds the tree and the state needed
  > to resume
  > it[[\[18\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=match%20at%20L371%20tree%20by,component).
  > Unreal's Mass StateTree uses *fragments* (Mass's term for
  > components) to track the active state and transitions for each
  > agent's state machine. If using an event-driven model (described
  > below), you might include a component like BTIdle or BTSuspended on
  > an entity to indicate the tree is waiting on an external event and
  > should not be ticked until that event occurs (thus the system can
  > skip it).

**Data Locality Considerations:** Organizing BT data to be
cache-friendly is crucial with many agents. A common pattern is
*Structure of Arrays (SoA)* for node state: e.g. instead of each entity
storing a struct with an array of 100 node states, you could have 100
arrays (one per node index) each storing the state for all entities.
This way, when you tick node 42 for 100 entities in a tight loop, you
iterate a contiguous array of 100 NodeState values -- which is great for
cache and vectorization. However, this is complex to implement unless a
large number of entities share the exact same tree structure. It's more
typical to use *Array of Structures (AoS)* at the per-entity level (each
agent has its compact state array) but try to ensure that array is
contiguous (e.g. allocate via ECS *DynamicBuffer* or a Blob).
EntitiesBT's design effectively achieves AoS per agent, but each such
array is in a blob asset likely adjacent for agents created in the same
archetype chunk (so memory layout is reasonably tight).

When BTs differ per entity (e.g. different species have different
trees), you lose some batching opportunities. In that case, consider
grouping agents by BT type (so they share the asset) and then processing
group by group. You could also chunk the ECS query by BT type if you
store a tree ID in the component, allowing the system to handle one tree
at a time (potentially important if you implement something like SIMD
optimized traversal for agents with identical trees).

**Entity per Node?** One naive ECS approach would be to make each BT
node an entity and link them via parent/child relationships (like a
graph in ECS data). This is generally **not recommended** for actual BT
ticking, because it would scatter nodes in memory and incur heavy
overhead (each tick would require multi-entity lookups). Instead, treat
the whole tree as *data* and the entity as the owner of that data\'s
state. You might still use entity hierarchy for editor convenience (e.g.
in Unity's authoring, nodes could be represented as child entities of an
"AI" entity just for visualization), but at runtime you'd collapse that
into a more efficient form (perhaps by baking into a blob or removing
the child entities). A flat data representation is easier to manage and
aligns with the idea that BTs are like *scripts* running on the entity.

In summary, use ECS components to store references to BT definitions and
the minimal per-instance data (node execution states, timers, blackboard
values). Opt for contiguous data layouts (blobs, buffers) for node info.
**Represent behavior trees as data-driven assets when you need designer
control or hot-reloading**, and as code when performance is paramount
and behaviors are static -- or combine the two by generating efficient
code from data definitions. The next section covers how these trees
actually execute within the ECS frame loop.

Execution Models in an ECS Context

**Standard Tick Per Entity:** The simplest execution model is to treat
the BT like any other update logic: every frame (or at a fixed
interval), run a system that ticks through the tree for each entity.
Pseudocode for an ECS BT system could look like:

System BTUpdate:  
For each (entity, BehaviorTree, Blackboard\...):  
TickNode(root, entity, blackboard)

Here TickNode would traverse the tree (depth-first) and update nodes
until it either completes or yields (finds a Running node). This is
analogous to a traditional BT loop but operating on ECS data. It's
straightforward but can become expensive if the trees are large or
numerous, since *each agent does a full traversal frequently*. In
practice, you'd optimize this by *early-outs* and partial ticks
(discussed below under time-slicing). Unity's DOTS example *EntitiesBT*
follows this model but with a twist: it schedules the BT tick as a
**job** across all entities, taking advantage of the data-oriented
layout to iterate quickly in
parallel[[\[19\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync).
In Unreal's Mass StateTree (a BT/StateMachine hybrid), each tick of the
state machine is also batched for many entities and highly optimized in
C++.

**Sequence/Selector/Decorator in ECS:** The BT control flow nodes
(composites and decorators) can be implemented without OOP by using
function logic or data-driven rules. In ECS, you typically implement the
node logic as *pure functions* that operate on the blackboard. For
example, a **Sequence** node will iterate its children in order each
tick: if any child fails, it returns failure immediately; if a child
returns running, it yields (so the sequence itself is "running"); if all
succeed, it returns success[[\[20\]]{.underline} HYPERLINK
\"https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:\~:text=This%20tree%20is%20really%20similar,execution%20order%20of%20their%20children\"[\[21\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=The%20numeric%20comment%20next%20to,parent%20task%20the%20tree%20ends).
A **Selector** (fallback) node does the opposite: it succeeds as soon as
one child succeeds, and only fails if all children
fail[[\[22\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=Image).
**Decorator** nodes wrap one child and modify its status or control its
execution -- e.g. an "Inverter" returns success when its child fails,
and vice versa. These can be handled in code easily; in data, you might
have a flag or type for each decorator that the tick logic checks. Many
ECS BT frameworks actually hard-code the logic for standard composites
rather than treat them as data, because they are fundamental and few in
number. For instance, Opsive's Behavior Designer Pro (DOTS version)
lists Sequence, Selector, Parallel, etc. as built-in composites that
determine
traversal[[\[23\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=,Conditional%20Evaluator).
So, your ECS BT tick function could have a switch or if-else on node
type: sequence vs selector vs action, etc., encoded perhaps as an enum
in node data.

**Time-Slicing and Long-Running Actions:** In a game, some BT actions
should span multiple frames (e.g. "move to location" might take several
seconds). There are a few models to handle this:

- **Internal Running State:** The classical way is that an action node
  > can return Running status to indicate "not finished yet; call me
  > again next tick". The BT traversal then stops unwinding at that node
  > and will call it again next frame (ensuring the higher parents know
  > it's still active). This requires that you maintain which node was
  > last running and resume from there -- typically that's why you store
  > NodeState per node. This model is *pull-based* -- each tick the BT
  > asks "are you done yet?" on that node until it returns
  > success/failure. It's simple but can waste CPU if you have many
  > waiting nodes that just check a condition every frame.

- **Event/Signal (Push-based):** An alternative is to make long actions
  > into *separate ECS processes* that notify the BT when complete. This
  > is the **spawn-and-wait pattern** used in Bevy Behave. For example,
  > when a "MoveTowardsPlayer" action node is reached, the BT spawns an
  > entity with a MoveTowards { target=player, speed=... } component and
  > then the BT node immediately *yields*. A separate system
  > (MovementSystem) processes all entities with MoveTowards and moves
  > them; once the move is finished (e.g. target reached), that system
  > or the entity itself triggers a success event. In Bevy, this is done
  > by the task entity calling commands.trigger(ctx.success()) to signal
  > its owning
  > BT[[\[24\]]{.underline}](https://www.hankruiger.com/posts/bevy-behave/#:~:text=%2F%2F%20the%20next%20step%20would%27ve,).
  > The BT system, meanwhile, has marked the tree as waiting. When the
  > event is received, the BT component knows which node it was waiting
  > on and resumes from there next tick. This *push model* is efficient:
  > the BT isn't doing anything for that agent until it's woken up by
  > the event. It also naturally parallelizes: hundreds of MoveTowards
  > tasks can be handled by one vectorized movement system, without the
  > overhead of each BT individually checking distances each frame. The
  > trade-off is complexity -- you need to manage these spawned entities
  > or tasks (ensuring they get cleaned up) and design the communication
  > (event, component flag, etc.). Bevy Behave spawns a child entity of
  > the agent for each running task and despawns it on
  > completion[[\[1\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned),
  > using a BehaveCtx component to tie the task back to its parent
  > BT[[\[25\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=match%20at%20L521%20of%20components,mechanism%20to%20generate%20status%20reports).

- **Coroutine-style (stack splitting):** A third model, somewhat between
  > the above, is to implement the BT like a coroutine that can yield.
  > This isn't straightforward in ECS directly (unless your language has
  > coroutine support), but you can simulate it by splitting the tree
  > processing across frames. For example, you could have the BT system
  > only process a maximum number of nodes per frame globally (to cap
  > CPU usage), and if it doesn't finish an entity's tree, store the
  > progress (which node was next) and continue next frame. This ensures
  > no frame spikes from BT, at the cost of slight latency in decisions.
  > If using this, you'd likely maintain an explicit stack per entity
  > (pointing to where in the traversal it was) -- which can be done via
  > a component or an indexed stack in a large array.

**Scheduling in Frame Loop:** Where exactly does BT updating happen in
the frame? In Unity's ECS, you might have a SimulationSystemGroup for AI
where the BT system runs after all sensing systems but before
movement/animation systems. It's important to schedule BT ticks *after*
the blackboard data has been updated for the frame (e.g. after you
update the agent's perception or any input stimuli), and *before* acting
on the decisions. Many architectures use a **Sense--Think--Act**
cycle: - *Sense systems:* update components like TargetVisible, Health,
etc. - *Think:* run BT or other AI logic to decide actions (set a
Decision component or spawn tasks). - *Act systems:* perform actions
like moving or shooting based on those decisions.

This ordering ensures the BT has fresh data and that decisions turn into
actions within the same frame. Some ECS frameworks (like Unreal Mass)
explicitly separate such phases using different *processors* or system
groups.

**Parallel Nodes and ECS:** Behavior Trees have **Parallel** composites
which attempt to run multiple branches
simultaneously[[\[26\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=One%20of%20the%20advantages%20of,time%20as%20their%20sibling%20branches).
Implementing a Parallel in ECS BT can be tricky, because "simultaneous"
in a single-threaded tick is relative. One approach is to treat a
Parallel node as spawning multiple sub-tasks: e.g. a Parallel with two
branches could internally split and track each branch's status in the
node state, ticking each child in turn each frame. If both children need
to be running truly concurrently, you might actually want to use the
event model: spawn separate entities or components for each child
branch. For example, a Parallel node that says "do X and Y at the same
time" could on tick create a child entity to handle subtree X while
continuing with Y on the main tree, and wait for both to finish. This
gets complex fast. In practice, many game AIs avoid the full generality
of Parallel in ECS; or they restrict it (like "Parallel Selector" where
one branch is just a monitoring condition). If using threads, you could
tick different subtrees on different threads, but synchronizing results
is overhead. The key is to keep track of each sub-branch's state in the
composite's state. If one branch finishes early and the other is still
running, the Parallel stays running. If one fails and the policy is to
stop all, you might need to abort the other (perhaps by signaling to its
tasks).

**Event-Driven and Priority Interrupts:** A big advantage of BTs is
reactivity -- higher-priority behaviors can preempt lower ones. In a
naive tick model that reevaluates the root each time, priority is
naturally checked each tick. But if you are *not* re-scanning the whole
tree every frame (e.g. to save CPU), you need a way to interrupt a
running branch when something important happens. This is where
**event-driven wakeups** or conditional aborts come in. Unity's Behavior
Designer (OOP edition) had *Conditional Abort* flags which monitor
blackboard changes and abort running branches if
needed[[\[11\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=With%20traditional%20behavior%20tree%20implementations,executed%20if%20the%20status%20changes).
In ECS, you can achieve similar by having systems that watch for certain
component changes and then setting a flag for the BT system. For
instance, if an agent is currently "Patrolling" (running that node) but
a new enemy appears (component EnemyVisible becomes true), a perception
system could directly set the BT's state to not running, or add a
component like HighPriorityEvent to the agent. The BT system on next
update sees that and either restarts the tree or jumps to a higher
priority branch. More systematically, you could encode priority
conditions as part of the tree (e.g. as guard decorator nodes that
always check EnemyVisible), and ensure those are evaluated frequently. A
fully event-driven BT might even skip ticking until an event of interest
occurs (some robotics BT frameworks do this). While that can be
efficient, it complicates the design -- a mix of periodic tick (for
regular updates) and event triggers (for urgent interrupts) often works
best.

**Frame Budgeting:** If your AI needs to run heavy logic, consider
distributing work over frames. For example, you can update 1/3 of your
AI entities each frame (each entity tick at \~20Hz if game runs 60Hz) --
effectively round-robin scheduling. This is easy in ECS: you can assign
agents a "batch" or use an index mod N to decide which ones to update.
This reduces per-frame cost but increases reaction latency slightly.
Another approach is to use *priority queues*: e.g. if you have an
expensive planning node that only some agents use, you could maintain a
queue of agents that need planning and only do a few per frame (storing
the result in a component when done). ECS's data parallelism makes it
tempting to update everything every frame, but for large scales,
controlled staggering and focusing on the most relevant AI each frame
(e.g. nearest to player) can help maintain frame budgets.

In summary, **choose an execution model that balances responsiveness and
performance**: - The simplest is a brute-force tick of all BTs each
frame (easy to implement, may be fine for dozens of agents but not
hundreds+ without multithreading). - A more advanced model is *spawn &
wait tasks*, which integrates elegantly with ECS and avoids idle looping
-- it's been used effectively in Rust (Bevy Behave) and can be adapted
to C++ or C#
ECS[[\[1\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned). -
Time-slicing and event-driven updates further cut down unnecessary work,
ensuring your BTs scale to large crowds of entities.

Next, we'll look at how to handle the **state and memory** in these BT
systems so that they run without garbage generation or cache misses.

State and Memory Management

Efficient memory usage is a cornerstone of ECS, and BTs should be
designed to avoid per-frame allocations and excessive indirection.
Several best practices have emerged:

**Stateless vs Stateful Nodes:** Ideally, BT nodes themselves hold no
mutable state between ticks -- any necessary state is kept externally
(in the entity's components or a parallel data structure). EntitiesBT
explicitly notes that *nodes have no internal
state*[[\[27\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=compatibility%20of%20other%20plugins.%20,tree%20into%20a%20binary%20file).
Why? Because if nodes are pure functions of the blackboard (plus perhaps
some constant parameters), then multiple entities can use the same node
logic without copies, and resetting a BT is trivial (just reset the
stored statuses). Some nodes naturally need state (e.g. a Wait node
needs to count time). In ECS, you'd implement that by writing to a
blackboard component or the node state array rather than a field in the
node object. For example, a "Wait 5 seconds" node could have an entry in
the node state array storing elapsed time for that entity, or simply
write a WakeUpTime component on the entity. Making nodes stateless in
themselves also helps with **serialization** -- the state that needs
saving is all in one place (the blackboard/components and the node
status list), which you can snapshot or replicate.

**Allocation-Free Ticks:** Ensure that your BT ticking doesn't allocate
memory or generate garbage. This means using structures like arrays,
pools, or ECS buffers that are pre-sized. Unity's EntitiesBT emphasizes
that after initialization it allocates virtually nothing per tick (aside
from a tiny scheduling
overhead)[[\[5\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync).
If you implement your tick with recursion in a managed language, be
careful about recursion depth and stack usage; an iterative approach
using an explicit stack structure (preallocated) might be safer for deep
trees. In C#, one might use Stack\<T\> or an array of node indices; in C
or C++ you could use a fixed-size array or std::vector reserved to max
depth. Another source of allocs is dynamic polymorphism -- avoid
interface calls or boxing in inner loops. Use struct-based nodes or
function pointers. If you have a dynamic data need (say, a node that
finds all enemies in range), try to reuse an ECS EntityQuery or a static
buffer for results instead of allocating a new list each time.

**Pooling and Reuse:** If your BT spawns entities for tasks or uses
events, consider pooling those to reduce churn. For example, if you
spawn a ProjectileAttackTask entity every time an agent shoots, you
could instead recycle a set of these task entities (mark them inactive
when done and reuse). However, in many ECS setups, the overhead of
creating/destroying entities is low if done in bulk via command buffers
-- so micro-optimizing pooling may not be necessary unless profiling
shows it. If using Unity ECS, use the EntityCommandBuffer system to
batch spawn/despawn of tasks per frame to avoid per-entity structural
changes.

For long-running tasks, you might also pool the *node state* if the same
agent repeats the task. E.g., if an agent enters a "Fight" subtree,
exits, then later re-enters it, ideally you've reset its nodes. Usually
a BT resets child nodes' state when you exit a composite early (so that
next time they start fresh) -- implement a **Reset** function for nodes.
EntitiesBT nodes have a Reset() method that is called to clear runtime
data when
needed[[\[28\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=public%20void%20Reset,).
This prevents old state from persisting incorrectly (like a timer not
reset).

**SoA vs AoS:** We touched on this in mapping section -- there's a
tension between organizing per-node vs per-entity. Structure-of-Arrays
(SoA) can yield better performance for homogeneous operations across
many entities (e.g. update the same node for 1000 entities in a tight
loop). Some ECS-like BT systems in robotics or simulation do this by
effectively advancing all BTs in lockstep step-by-step. However, in
games, agents often diverge in behavior, so lockstep isn't feasible
beyond the root or high-level nodes. Thus, **hybrid approach**: keep
each agent's data contiguous (AoS), but when performing an expensive
operation, consider doing it in bulk outside the BT. For example,
pathfinding requests from many agents could be collected and then
processed together, rather than each BT computing path individually.

**Memory Layout of BT Assets:** If using a data-driven BT, how you store
the tree matters. Many implementations use a flat array of nodes with
indices for parent/child relationships. This is cache-friendly compared
to a pointer-heavy tree. You can store for each node: its type,
parameters, indices of its children (or an offset to the first child and
count). This way, traversing the tree is just index arithmetic. Make
sure to choose appropriate data types (e.g. 16-bit indices if your tree
is small, to cut memory footprint). If you have large numbers of similar
nodes, you could even separate data by type (e.g. parallel arrays: one
array of floats for all "wait time" parameters, etc.) -- though this
might be overkill.

**Blackboard Memory:** Decide if blackboard values live on the entity
(as standard ECS components) or in an external store. Per-entity
components are great for performance (straight memory access in chunks)
and for systems outside BT to use. Shared blackboards or tree-specific
blackboards might need separate storage (like a Blob or a Map from key
to value). Unity's new Behavior package, for instance, introduced a
blackboard asset and uses keys to access it; that's more OOP-style. In
ECS, it's often simpler: *use the data already on the entity.* If a
behavior needs a local variable that isn't otherwise an ECS component,
you can create a component for it (even if just a tag or a single
float). Example: a BT "Investigate" subtree might need to store "last
heard noise position" -- instead of using a BT-specific memory, just put
a LastHeardNoisePosition component on the entity that both the hearing
system and the BT can use. The lifetime and ownership of such components
should be managed (e.g. remove it when not needed). Alternatively, use
an ECS *DynamicBuffer* on the entity as a generic storage for misc
variables (like a dictionary). Some frameworks have a notion of
*variant* that can map to different sources -- EntitiesBT's **Variant**
system allows a node to declare a variable and bind it either to a
component, a local blob field, or even a
ScriptableObject[[\[29\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,NodeData).
This flexibility lets you avoid lots of boilerplate for passing data
around, while still keeping within safe memory.

**Serialization & Hot-Reload:** If you want to save/load the BT state
(for savegames or live editing), it's easier if your BT state is just
component data. That can be serialized by the engine's existing
serializers (or a custom one). For example, you'd serialize the current
node statuses, the blackboard components, and perhaps an identifier of
the current running node if needed. Hot-reloading a BT (swapping its
structure at runtime) is inherently hard if agents are mid-behavior. A
pragmatic approach is to design BTs to be replaceable only at certain
boundaries (like between high-level behaviors). For instance, you could
use a component to indicate an AI's "BehaviorType" and have systems
switch the BT asset when that changes (ensuring the old one is
gracefully stopped). Unreal's StateTree is built with the idea of being
data-driven and performant, but even it cautions that it's experimental
to change tree assets on the fly. If live tuning is required (common in
development), one strategy is to run a **debugging BT in parallel**:
e.g. have an agent run the old BT controlling it, while you simulate the
new BT on a ghost copy of the entity to see how it behaves, then switch
when confident -- this is complex but can be done with ECS (since you
can create a duplicate entity or use the same blackboard data in two BT
systems and compare outputs).

**Minimizing Dynamic Dispatch:** Traditional BT implementations often
use polymorphic objects for nodes with virtual update methods. In ECS,
avoid that. Instead, use **data-oriented dispatch**: e.g. each node type
could be an enum tag and you use a big switch as mentioned, or function
pointers in an array indexed by node type. In C++, you might use
templates or static polymorphism; in Rust, you can use enums with match
(optimized via compilers). In C#, you might use function delegates or
switch on an integer node type -- which, if designed well, will get
inlined or jump-tabled for efficiency. The goal is that ticking a node
doesn't go through a vtable -- that would wreck performance with many
entities. EntitiesBT uses C# generics trickery to avoid boxing and
interface calls (each node struct implements a generic
Tick\<TNodeBlob,TBlackboard\> which JIT can specialize per
usage)[[\[30\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=public%20NodeState%20Tick,deltaTime.Value).

**Memory Cleanup:** If an entity or the whole BT system is removed,
ensure you clean up any associated allocations. If you used blob assets,
reference counts or proper destruction is needed (Unity ECS will dispose
blobs if asked; in C++ you'd free the memory). If you spawned task
entities, they should self-destruct or be collected when no longer
needed (Bevy Behave automatically despawns task entities on
completion[[\[31\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned)).
Memory leaks in AI can be subtle -- e.g. forgetting to reset a static
event list or never clearing a buffer of past actions.

In summary, **conserve memory and keep it contiguous**: - Preallocate
what you can (node states, stacks). - Use ECS components for transient
data instead of heap allocs. - Favor stateless nodes and externalize any
necessary state to ECS data that's easier to manage. - Profile for GC or
allocation hot spots and refactor them (for example, replacing a growing
list with a fixed-size ring buffer in a component). - Test that you can
create and destroy agents frequently without problems -- e.g. if an
agent dies and respawns with a BT, does everything reset correctly or
are there lingering states? Proper reset logic and pooling ensures
memory is reused safely.

With state and memory under control, we can move to how nodes safely
access and modify the game data without breaking ECS rules or
performance.

Data Access and Safety in BT Nodes

Behavior nodes ultimately need to read and write game state: an AI
decides to move, it must update a position; it senses an enemy, it must
query a list of enemies. In ECS, direct random access to components can
violate the rules of the paradigm (especially with parallel jobs) and
hurt performance if done naively. Here's how to do it right:

**Blackboard as Interface:** We've mentioned using components as
blackboard data. The BT node code should interface with components in a
controlled way. In EntitiesBT, the blackboard passed into nodes provides
typed accessors like bb.GetData\<Translation\>() or
bb.GetDataRef\<Health\>()[[\[6\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,Running%3B).
Under the hood, this might be doing an ECS ComponentLookup or simply
pointing to the entity's component data in memory. The advantage is that
all data access goes through a uniform API, which can enforce read-only
vs read-write rules at compile time. For example, EntitiesBT defines
BlobVariantReader vs BlobVariantWriter to mark whether a node intends to
read or write a blackboard
variable[[\[32\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=).
If a node only has read access, the system can safely run it in a job in
parallel with other reads (since no writes happen). If a node needs to
write, that might force it to run single-threaded or use a command
buffer.

When designing your BT, **separate nodes that purely query state from
nodes that modify state**, as much as possible. This follows the ECS
concept of having systems either read or write specific components in a
controlled way. A condition node (like "Is Hungry?") should likely only
read the Hunger component -- it doesn't change anything, just returns
success/failure. An action node ("EatFood") will modify Hunger (reducing
it). If you blur those responsibilities, you risk either doing
unintended work or complicating scheduling (e.g. a condition that also
tweaks something is bad practice).

**Deferred Writes via Command Buffers:** In a multithreaded ECS update
(Unity's Jobs or similar), you cannot generally write directly to a
component from within a parallel job without risk of race conditions
(unless you guarantee exclusive access). A common solution is to
accumulate changes and apply them later. ECS frameworks have **Command
Buffers / Events** for this. For example, a BT node that wants to spawn
an entity or change a component could call a function that records this
in a command buffer. Unity's ECS uses EntityCommandBuffer which can
record structural changes and play them back safely at the end of the
system update. If you implement your own, you could have a global or
per-thread buffer where nodes push "commands" like "entity X: set
AlertLevel=High" or "spawn entity of type Bullet at position Y". Then,
after ticking all BTs, a follow-up system executes these commands in a
safe context (main thread or controlled single-writer phase). This
decoupling is similar to how rendering or physics might be handled, and
it ensures that the BT tick can be parallelized without immediate side
effects.

Note that not every node needs deferred logic -- if you are in a
single-thread context (e.g. during development or using an explicit
single-thread mode), you might directly set components. EntitiesBT
provides modes to force BT execution on the main thread specifically so
that nodes *can* safely call UnityEngine or make immediate changes if
needed[[\[8\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,once%20meet%20decorator%20of%20RunOnMainThread).
So you have flexibility: during gameplay, run BT in jobs and restrict
nodes to safe operations; but for tricky nodes (like one that plays an
animation trigger on an entity), either mark them to run on main thread
or implement them via events (the node posts an "AnimationTrigger" event
and an AnimationSystem consumes it to actually play it).

**Batching and Minimizing Random Access:** If a BT node needs to access
data not on the agent entity (say, check a target entity's component or
a global singleton), be cautious. Randomly accessing unrelated entities
breaks data locality and could cause sync points. Instead, *mirror
needed data onto the agent's components if possible.* For example, if an
AI needs to know an enemy's health, you might have already stored the
enemy's health in a component on the AI (like TargetHealth) as part of a
sensing system, so the BT doesn't chase a pointer to the enemy mid-tick.
If that's not feasible, consider using ECS queries -- e.g. find the
entity via some index and then get its component. But if you do that for
many agents, it's slow. A better approach is a **batch query**: outside
of BT, run a system that, for each AI with a target, reads the target's
Health and writes it into the AI's TargetHealth component. Now the BT
just reads TargetHealth locally.

Another example: instead of each BT doing a distance check to see if the
player is near, have a system compute a boolean "PlayerNear" for all
relevant entities (could be based on distance or trigger volumes) and
store that on the entity or in a global. Then BT conditions simply check
that boolean. This leverages ECS strengths (iterating over many entities
with vectorized math) rather than doing ad-hoc checks in scripted nodes.

**Avoiding Uncontrolled Side Effects:** Behavior Trees are essentially
imperative logic, but in ECS we try to keep systems as the units of side
effects. If you embed too many direct effects in BT nodes, debugging can
get hard (since the order might be tricky or if something fails
mid-tree, you might have partially applied changes). A pattern to
consider is to have BT nodes *set intentions* rather than perform
actions directly. For instance, instead of a node that directly reduces
the health of a target (which is an instantaneous effect), have the node
add a AttackTarget component to the agent (or target) with details like
"attacker X intends to hit for Y damage". Then a separate CombatSystem
sees that and applies the damage. This way, all actual health
modifications go through one system (easy to debug, can handle multiple
attacks gracefully, etc.). The BT remains high-level and declarative.
This isn't always needed (simple things like playing a sound could be
done in-node with a direct call if on main thread), but for any complex
effect, decoupling is beneficial.

**Race Conditions and Invariants:** If you do allow BT nodes to write
directly to components, be mindful of invariants. For example, if two
different nodes in the tree could potentially modify the same component
on an entity in one tick (maybe via Parallel branches), you must define
what happens. Ideally avoid such a situation -- ensure that at most one
branch can write to a given component at a time. If using the spawn
model, it's naturally separated (two tasks won't usually try to write
the same thing simultaneously). But if not, you might need to enforce an
order (e.g. give one branch higher priority to write first) or lock it
(which is against ECS, so better to avoid).

Consider also what happens if a BT is interrupted: did it leave a
component in an inconsistent state? A classic example is a "MoveTo" node
-- if it's halfway and then an interrupt causes a switch to "RunAway",
maybe you want to cancel the move command. If you implemented move via a
task entity, you'd simply despawn that entity (or set a cancel flag). If
you implemented it by setting a component like MoveTarget on the agent,
you need to remember to clear that component when the BT branch aborts.
Some BT frameworks handle this via **scoped cleanup**: a higher-level
composite knows what to clean up if its child is aborted. You can
implement cleanup actions as special nodes (e.g. a Decorator that on
abort executes a cleanup lambda, or using the Reset() calls in
EntitiesBT which could handle resetting component
values)[[\[28\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=public%20void%20Reset,).
Decide and document which nodes require cleanup so that designers don't
misuse them (for instance, a node that reserves a resource in the world
should have a matching release if it fails or is aborted).

**Read/Write Access Control:** If your ECS allows it, declare in your
system or job which components are read vs written by the BT. For
example, Unity's Systems can specify \[ReadOnly\] on certain component
data arrays. This ties into performance (to allow parallel reads) and
safety (to catch writes where not allowed). If writing, do it in a way
that doesn't conflict with other systems in the same frame -- e.g. maybe
run BT writes in a particular system after other reading systems. Some
ECSs like Flecs allow *deferred mode*, where entity modifications inside
a system are buffered automatically. If using Flecs, you might leverage
that so BT logic can call ecs_set freely and it will apply after the
iteration.

**Example -- Safe Node Implementation:** To make this concrete, consider
implementing a simple **MoveTowards** action node in ECS: - The node
needs to move the agent toward a target position each tick and report
Success when reached. - We decide the agent has components: Position,
Speed, and maybe TargetPosition. - The MoveTowards node on tick will
read Position and TargetPosition, compute a new Position, and write it
back, and also determine success/failure. - In a single-thread context,
the node function could do:

ref float3 pos = ref bb.GetDataRef\<Position\>();  
float3 target = bb.GetData\<TargetPosition\>();  
float speed = bb.GetData\<Speed\>();  
float3 toTarget = target - pos;  
float dist = length(toTarget);  
if (dist \< 0.1f) { return Success; }  
float3 step = normalize(toTarget) \* speed \* DeltaTime;  
if (length(step) \>= dist) {  
pos = target;  
return Success;  
} else {  
pos += step;  
return Running;  
}

This is similar to how EntitiesBT example nodes manipulate
Translation[[\[6\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,Running%3B).
It directly writes to pos (Position) by ref. In a Unity job, doing that
would require exclusive access to Position, so likely this node would be
scheduled to run on main thread or run under a write lock. An
alternative is to not write directly: instead, output the intended
movement. For instance, the node could output a MoveDelta component or
an event "move X units" and let another system apply it. That way the
node remains read-only to Position and can run in parallel, and the
actual movement application is centralized.

- If we had thousands of agents moving, a better approach might be to
  > *not do movement in the BT node at all*, but simply set a Moving
  > flag or desired velocity, and let a physics/movement system handle
  > positions for all agents together. This again is decoupling: BT sets
  > intent ("I want to move there") and another system does the heavy
  > lifting. This pattern appears in the **Mass AI** in Unreal -- the
  > StateTree sets high-level state, and the MassMovement processors
  > handle actual movement for potentially 1000s of entities
  > efficiently.

**Conclusion on Safety:** Treat BT nodes as part of the ECS system
ecosystem -- they shouldn\'t be doing anything that a normal ECS system
couldn\'t in terms of data access. Use the same discipline: *prefer pure
functions, isolate side effects, use events for cross-entity
interaction, and batch where possible.* This will keep your AI both fast
and reliable. Now, let's discuss how to author these behavior trees and
what tools can assist in building and debugging them in an ECS
environment.

Authoring and Tooling for ECS Behavior Trees

Designing AI with BTs can be done through code or visual editors, and in
ECS you often want to preserve some of the ease-of-use of traditional BT
tools while adhering to data-oriented principles.

**Code-Driven Authoring:** Some developers define BTs in code using
builder functions or macros. For instance, the Rust crate bevior_tree
allows constructing a tree with a Rust DSL in code (as seen in its
examples like chase.rs) -- you might write something like:

let tree = Sequence(\[  
Condition(\|\| check_something()),  
Selector(\[ Action(foo), Action(bar) \])  
\]);

In C++, one could use a fluent API or template metaprogramming. The
advantage is strong compile-time checks (if foo expects a certain
blackboard type, the compiler can enforce it) and no need for external
tools. The downside is iteration time and accessibility -- designers who
don't code will find this difficult, and even for programmers, large
trees get unwieldy in code. Code-driven BTs also mean you can't easily
tweak behavior without recompiling. However, they excel in
*maintainability* when AI behaviors are relatively static or generated
from data: you can have version control on behavior logic and use all
your language's abstractions (loops, constants, etc.) to avoid
repetitive structures.

**Data-Driven Authoring (Visual Graphs):** Many ECS BT solutions
incorporate or adapt visual editors. Unity's MBT (MonoBehaviour BT)
tools like Behavior Designer, NodeCanvas, etc., come with node-based
editors. Unity's DOTS-friendly BT frameworks also attempted similar:
EntitiesBT included a GraphView editor to create the tree and then
**bake it into components** on an entity for
runtime[[\[33\]]{.underline} HYPERLINK
\"https://github.com/quabug/EntitiesBT#:\~:text=\"[\[34\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=).
Essentially, at edit time you assemble a graph, and a "Baker" or build
step converts that into the blob asset and adds the necessary components
(like BehaviorTree component pointing to the blob, etc.). Unreal's
StateTree has an editor in Unreal Engine where you drag and drop states
and tasks, then it compiles that into data for Mass.

If you roll your own, you could utilize a generic graph editor (if
available) or even represent the BT in an intermediate format like JSON
or a custom text (BehaviorTree.CPP, a C++ library, uses an XML format
for trees, for example). The pipeline would then parse that into your
ECS data at load time. **Reflection/Registry:** To support data-driven
authoring, you need a registry of node types and their properties. For
example, if you have a node "MoveToCover" that has a parameter
"CoverTag", your editor needs to know that so it can present it and save
it. In EntitiesBT, nodes are tagged with a GUID and implemented as
structs with
attributes[[\[35\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=%2F%2F%20most%20important%20part%20of,INodeBlob).
At compile time or startup, they likely register these GUIDs to the
struct types, so when a blob asset is built from the editor data, it can
map "MoveToCover (GUID abc)" to the actual INodeData struct and copy its
default values in. If you plan on making a custom editor, leveraging
existing serialization is key -- e.g. Unity's editor can serialize
MonoBehaviour fields, so EntitiesBT cleverly uses authoring components
to represent nodes (so Unity's inspector is used rather than building a
whole new
editor)[[\[3\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,with%20Unity%20GameObject%20without%20entity).

**Hybrid Authoring:** Some projects use code for basic structure and
data for tweaking. For instance, you might hardcode the high-level flow
in code (to ensure performance and determinism), but allow some subtrees
to be data-driven for flexibility. Or use data-driven BTs but allow
scriptable *actions* within them. Unreal's BTs allow calling C++ or
Blueprint functions in the leaf nodes. In ECS, you might allow a node
that calls a function pointer (set via data) -- but be careful with that
in a job environment (function pointers might not be Burst-compatible,
etc.). Alternatively, design a small scripting language for certain
decisions and interpret it in a node -- though this could slow things
down.

**Debugging and Visualization:** One of the strengths of BTs is the
visual trace (seeing which node is active). For ECS BTs, similar debug
views have been built. EntitiesBT, for example, provides a runtime debug
window showing the state of nodes on a selected
entity[[\[10\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync).
Unity's DOTS debugging is a bit manual, but they even had an example
where each node's state was exposed as a component so it could be viewed
in the Entity Debugger. A simple approach is: when running in editor/dev
mode, have a system that reads all entities' BT node states and if an
entity is selected (or always), output a tree diagram with highlighting
of running nodes. This could be a custom IMGUI panel or just logs. Since
the data is there (node array with statuses), it's a matter of mapping
it to the tree structure. You can store parent indices or a tree
descriptor to help reconstruct the hierarchy for debugging.

Another useful debugging feature is **step-by-step execution** --
pausing the game and advancing the BT logic one node at a time. This is
hard in a live game loop, but you can simulate by running the BT for one
entity outside the main loop. For example, write a little function that
takes an entity's BT data and ticks it once, and call that manually from
a debugging console. In Unity, you might integrate with their
MonoBehaviour Update while the ECS World is paused. These are advanced
use-cases, but very helpful for complex AI bugs (like why did it choose
this branch?).

**Timeline Traces:** Logging each decision over time can be invaluable.
You can instrument your BT system to emit events (like "Entity X entered
node Y at time T with result R"). Using an ECS event component or a
simple DebugLog component that accumulates strings can work (though
heavy). A more efficient way is to record only certain milestones (e.g.
"attack started" or "state changed from patrol to chase"). Those can be
logged via the game's logging or a file. Some AI devs even build a
timeline UI that shows entities on one axis and time on another with
colored bars for which BT branch was active -- this is great for finding
patterns or synchronization issues. If that's too much, at least make
liberal use of conditional logging controlled by some debug flags in the
BT (like a Decorator that logs when a branch runs, only compiled in
debug builds).

**Telemetry:** Over long play sessions or simulations, you may want to
gather statistics. ECS makes it straightforward: you can have a
component that counts how many times an action was done or how long an
agent has been in a state. Alternatively, a central system could
aggregate stats from all BTs (like average decision time, most
frequently failing condition, etc.). This can guide optimizations
(finding hot nodes) or game design adjustments (e.g. NPCs always choose
the same behavior -- maybe add variance). One particular telemetry to
consider is **BT usage frequency**: e.g. how often each node returns
each status. You might embed a small array in the BT asset for counts,
but since multiple entities share that, it could become a data race.
Better is to track per entity and then sum up offline.

**Tooling in Specific Ecosystems:** - *Unity DOTS:* As of 2025, Unity's
official DOTS hasn't provided a built-in BT solution (their
com.unity.behavior seems focused on GameObject world). So tools like
Opsive's Behavior Designer Pro fill the gap. Behavior Designer Pro
allows authoring BTs similarly to the old version but *bakes them to
DOTS under the hood*, letting you use ECS without directly dealing with
it[[\[36\]]{.underline} HYPERLINK
\"http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/#:\~:text=with%20it%20and%20can%20respond\"[\[37\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=Behavior%20Designer%20Pro%20is%20the,that%20you%20are%20using%20it).
It provides an editor and handles the conversion to ECS (including an
**Entity Baking** step in their
docs[[\[38\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=,48)).
If using Unity, leveraging such a tool can save time, as it integrates
with their animation, variables, etc., in a designer-friendly way while
still being data-oriented in runtime. - *Bevy (Rust):* The community has
bevy_behave and bevior_tree as mentioned. They use Rust macros for
definition and spawn approach for tasks. Rust doesn\'t have an official
editor, but one could imagine a small editor in egui or a text format.
For now, Rust users likely code the BT structure or load from ron/toml
files. - *Flecs (C):* Flecs doesn't have a dedicated BT tool, but you
could use Flecs's *entity hierarchies or pipelines* in creative ways.
Sander Mertens (author of Flecs) often demonstrates creative design
patterns, but BT would require you to implement the tick logic yourself
(possibly as a system that iterates a tree representation). - *EnTT
(C++):* Similarly, EnTT provides ECS building blocks but no high-level
AI. You could integrate a library like BehaviorTree.CPP with EnTT: run
the BT tick in an EnTT system, and have conditions/actions read/write
EnTT components. BehaviorTree.CPP even supports a blackboard, though
it's OOP in design. Adapting it to EnTT might negate some ECS benefits
unless you carefully wrap it.

**Reflection & Versioning:** When you change a BT asset (add/remove
nodes), you may need to migrate existing saved data or live entities.
Plan for a version number or ID on your tree assets. A simple approach:
whenever you load a save, if the BT asset version doesn't match, you
might just reset all BT state (losing any running nodes) -- possibly
acceptable, or you write a custom migration (not trivial). During
development, this is less an issue; for shipped games, consider locking
the BT asset formats or building migration into patches.

**Integrating Other AI Techniques:** Sometimes you want a mix (BT plus
Utility AI or BT plus Planning). Tooling-wise, this could mean having,
say, a special BT node that calls a Utility evaluation or a planner.
Ensure your architecture is flexible: e.g. you might register a node
type \"UtilitySelector\" that given some scores picks a child. Provide
designers with ways to influence scores via data (curves, weights). The
BT tool should then expose those parameters. It's beyond scope here, but
note that if you integrate Utility AI or GOAP (planning) as part of an
ECS BT, treat them as black-box tasks or decorators, and leverage ECS
for their data (e.g. a GOAP planner system can run separately and just
feed a plan into the BT as a series of sub-actions).

In summary, **authoring ECS BTs** can be as user-friendly as traditional
BTs if you invest in the tooling -- many frameworks have shown it's
possible to keep the visual paradigm (nodes, connectors) and simply have
a different runtime backend. Use reflection and codegen to avoid writing
boilerplate for each node type. Provide rich debugging support because
ECS can be harder to visualize than OOP (no GameObject inspector to
click through behavior scripts). And always keep one foot in the data:
if a designer says "I want this AI to do X in situation Y", ensure you
have a way to represent "situation Y" in components or blackboard so the
BT can reliably detect it. That often means expanding tooling to define
new condition nodes or exposing new game data to the AI.

Next, we will compile the **performance and scaling** considerations
already touched on, and how to practically measure and optimize a BT in
ECS for large-scale scenarios.

Performance and Scaling Strategies

When dealing with potentially thousands of entities running behavior
trees, performance optimizations are not optional -- they're required.
ECS is chosen often for its ability to scale, so we want to ensure our
BT implementation leverages that fully. Here are strategies and
considerations:

**Controlled Update Frequencies:** Not every AI needs to think every
frame. Introduce *tick rate* control for BTs. This could be as simple as
a component NextThinkTime (or a countdown timer) that you decrement each
frame and only tick the BT when it hits 0, then reset it to a desired
interval (like 0.1s for 10Hz thinking). You might vary this per entity:
e.g. enemies near the player get 10Hz, far ones get 2Hz. Unity's AI
packages often allow setting update interval; you can do this manually
in ECS. Another method is to distribute updates over frames: e.g. assign
each AI an ID and only update those whose (ID % N) == (Frame % N) for a
given N. This is a deterministic way to spread load. Be careful that if
you slow the tick too much, the AI might appear unresponsive (e.g. a
0.5s delay in noticing something can be noticeable). But slight delays
can be fine, especially if you also allow immediate event interrupts on
critical changes (hybrid approach: event for high-priority, slower
polling for others).

**Level-of-Detail (LOD) AI:** This is an extension of variable tick
rates -- LOD can also mean *simpler logic* for far-away agents. For
instance, a crowd NPC in the distance might not run a full decision
tree; instead it could be in a simplified state machine or have a
"background behavior" (like wander randomly). If the NPC comes into
focus, you swap in the full BT (perhaps by adding the BT component and
removing the simple AI component). ECS makes swapping behaviors
relatively easy: you can have an AIType tag that you change, and systems
will automatically start/stop affecting that entity according to its
archetype. The tricky part is transferring state -- the simple AI might
have to inform the BT of what it was doing if you want continuity.
Often, though, you can get away with abrupt changes for distant NPCs
(players won't notice minor pops in behavior at long range). Unreal
Engine's Mass framework uses the concept of *representation LOD* for
crowds, which includes AI detail; e.g. only nearest agents do full
avoidance and decision-making, others follow spline paths or are on
rails.

**Selective Ticking (Dirty Bits):** We discussed event-driven updates:
essentially treating some conditions as "dirty flags" that wake the AI.
You can extend this to whole trees. For example, if an NPC is idle (no
enemies seen, just patrolling), you might not need to run the BT at full
rate; you could let a Patrol system handle movement and only invoke the
BT when something notable changes (player spotted, took damage, etc.).
This can be done by having the BT system ignore entities in an "Idle"
state and only change them to "Alert" (thus enabling BT) when an event
triggers it. This is akin to **behavior state machines** at a high level
gating when the expensive BT logic runs. Some games use Utility AI at a
high level to decide "should I even run my BT or which BT to run?" --
though that may be over-engineering. Simpler: use ECS event triggers to
only tick AI when needed. This requires discipline to ensure no event =
no tick; e.g. a guard who never sees anything might never tick -- if
that's okay (maybe it just stands idle forever) then fine; if not (maybe
it should yawn occasionally), then you need a periodic wake-up as well.

**Parallelization:** Modern ECS (Unity DOTS, Flecs, etc.) can
multi-thread across entities. Split your BT evaluation into jobs if
possible. In Unity, you could do:

Entities  
.WithAll\<BehaviorTree\>()  
.ForEach((ref BehaviorTree bt, ref Blackboard bb) =\> { \...Tick
logic\... })  
.ScheduleParallel();

If the tick logic doesn't call any non-threadsafe APIs and each entity
is independent, this will utilize multiple cores
automatically[[\[8\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,once%20meet%20decorator%20of%20RunOnMainThread).
Ensure you partition work in a cache-friendly way: sometimes one large
job is fine, sometimes splitting by chunks yields better load balancing.
In C++ (EnTT or custom), you might use a thread pool to divide entities
set into parts. The challenge is if you have to lock on some global
data. Try to design nodes to avoid global locks -- e.g. if all AIs are
trying to write to a single "last seen player position" global, that's a
bottleneck. Instead, either make that read-only or partition it (each AI
writes to its own component, or one per team, etc.). Use atomic
operations sparingly (only if truly needed for counters or so).

**Jobifying Long Tasks:** For computationally heavy leaf nodes (like
pathfinding, complex line-of-sight checks, or decision simulations),
consider using separate job systems. For example, an A *pathfind might
be too slow to run inside the BT tick for each entity. Instead, a node
could enqueue a path request to a pathfinding subsystem (which runs in
its own threads, perhaps grouping requests and using specialized
algorithms). The BT node would then yield (Running) and complete when
the result is available. This is similar to event-driven, but
specifically about offloading CPU-heavy work to specialized threads.
With ECS, you might maintain a component like
PathRequest{start,destination,result} and a system that picks those up,
does a batch pathfinding (maybe using a library like Recast, or a custom
parallel A*), then writes the results into a PathResult component. The
BT then sees the PathResult and either continues to follow it or fails
if none found. This way, the main BT logic stays responsive.

**Contention Hotspots:** If you profile and see a specific part of the
BT consuming a lot of time, that's a hotspot. Common ones include:
distance calculations (especially if doing sqrt for many agents --
consider working in squared distances to avoid sqrt), frequent sorting
or list operations (like picking nearest target by sorting distances --
instead, maintain spatial partitioning or do one pass to find min), too
many logs or debug checks (strip them out in release). **Work stealing**
might be relevant if the distribution of BT complexity per entity is
uneven (some agents have huge trees or are in expensive branches). Most
ECS jobs frameworks handle load balancing by splitting by count of
entities, which might not perfectly equal work (one entity might be
doing an expensive search, another just idling). If this becomes an
issue, you could categorize entities by workload and schedule separate
jobs. Or within a job, if a particularly expensive node is encountered,
break out and handle it differently. This gets very low-level; only do
such tweaks if you have evidence of imbalance.

**Scaling to Thousands of Agents:** When numbers grow, little
inefficiencies multiply. Ensure memory access is linear where possible.
Also, watch out for memory *bandwidth*: thousands of entities mean
thousands of component fetches. Align data to cache lines and try to
pack what's frequently used together. For example, if your BT often
checks 3 components (say Health, Stamina, EnemyVisible), and those are
all booleans or small, consider grouping them in one component (so one
memory access brings all needed flags). Or use bitfields for booleans to
pack them. However, don\'t prematurely pack unrelated data, as it could
cause false sharing if some systems write one field and others read
another on the same cache line.

In practice, one of the biggest wins for large scale AI is *culling*:
don't update what you don't need. For instance, if agents are far
outside the play area or currently inactive (maybe waiting in a pool),
exclude them from systems by requiring an "Active" tag. If using Unity,
use disable/enable on entities or simply remove the BT component when
not in use. Unused AI shouldn't tick at all.

**Cache Behavior and False Sharing:** If running multi-threaded, be
mindful of false sharing -- if two threads update data on the same cache
line, they'll fight. Node state arrays might suffer from this if not
padded: e.g. if NodeState is an enum (size 1 byte) and thread A updates
entity 1's states\[5\] while thread B updates entity 2's states\[5\],
and if those happen to lie on same cache line because the arrays are
interleaved in memory, you get contention. A solution is to structure
the array per entity (so no interleaving) or pad it out (but that wastes
memory). Usually, each entity's NodeState array is separate memory, so
no false sharing *between* entities. But if you store all entities'
states in one big array per node index (SoA style), then index 5 array
has all entities' states for that node -- two threads processing
different entities *will* hit the same array. In such cases, you might
want to chunk that array by thread or use atomic operations carefully.
This shows how data layout can affect thread performance, not just
single-thread speed.

**Measurement Methodology:** Always profile with a scenario that
represents your worst-case or target case (e.g. 1000 agents all active).
Use profiling tools to measure where time is spent: in which system,
maybe which node type. In Unity, Profile markers in jobs can help (or
attaching a profiler to the running build). In C++, use CPU timers or
telemetry counters. Also measure memory usage -- large BT assets or
state arrays for 1000 agents might take significant memory, which could
impact cache. If you can, simulate headless (no rendering) to isolate AI
cost. Another tip: vary the complexity and count to see non-linearities
(if 500 agents cost X ms, does 1000 cost 2X or more than 2X? If more,
maybe some overhead isn't scaling linearly).

**Example Case Study:** Suppose we have 1000 zombie agents with a
moderately complex BT (say 30 nodes). Each has to wander, chase players,
attack, etc. Initially, we tick all every frame -- assume it's too slow
(e.g. 10 ms just on AI). We then decide: only tick each zombie's BT
every 3 frames on a staggered schedule (now each frame \~333 BTs tick,
smoothing cost, maybe \~3-4ms per frame). We also implement an event so
that if a player makes a noise, any zombies that heard it get their BT
tick immediately (so they don't wait up to 3 frames). We profile again
and see improvement. Then we notice pathfinding is spiking when many
zombies chase simultaneously. We offload pathfinding to a single BFS
that finds a path from player to each zombie or we limit path
computations to e.g. 20 per frame globally. We also ensure that the
"idle shambling" of distant zombies is handled by a simpler system
(maybe a noise-based wandering that doesn't require BTs at all). In the
end, our AI runs within \<2 ms at peak. This sort of iterative tuning is
typical -- you combine several tactics: throttling updates, parallel
execution, splitting responsibilities, and culling.

To conclude, **scaling AI in ECS** is about using data-oriented
optimizations (batching, parallelism) and algorithmic optimizations (do
less work, or work smarter) in tandem. ECS gives you the tools to
organize and filter updates flexibly -- use tags or components to
segment which AIs do what and when. Profile often, because the
bottleneck might be non-intuitive (maybe a trivial-sounding node like a
random selector could be calling RNG in a way that stalls SIMD, etc.).

Finally, we'll consider testing and ensuring deterministic behavior,
which is often important for correctness and multiplayer.

Testing and Determinism of ECS Behavior Trees

Testing AI can be challenging because of the non-deterministic and
complex interactions, but ECS can aid in creating reproducible test
scenarios. Here are best practices:

**Unit Testing Nodes:** Treat each leaf node's logic as you would a
function -- write unit tests for it if possible. If a node is a pure
function (e.g. condition checks if health \< 30%), that's easy: feed in
blackboard values and assert the output. If a node has side effects, you
might have to simulate a tiny world state. For example, to test a
"FireWeapon" node, create an entity with the necessary components (Ammo,
Target, etc.), run the node's tick function in isolation, and check that
the expected effects (maybe a Projectile entity spawned or Ammo
decreased) occurred. Because ECS is data-driven, you can set up these
tests by directly manipulating components and then calling the node
logic. In Unity DOTS, you might instantiate a temporary EntityManager in
edit mode for testing, add components, and call your system or node
code. In Rust, you could create a World, insert test entities, run the
schedule for a tick, and verify outcomes.

**Scenario Tests (Integration):** Build small scenarios to test
sequences of behavior. For instance, "Agent sees enemy, chases, and
attacks" -- you want to verify the BT transitions through the expected
nodes (See -\> Chase -\> Attack) and produces the right results (enemy's
health reduced). You can automate this by scripting the environment:
place an agent and enemy entity at certain positions, run the systems
for enough frames, and then inspect component states. If possible, also
assert on BT internal state: e.g., check that by frame 5 the agent's BT
is in "ChaseEnemy" node (maybe indicated by some state component or by
checking that a MovingToTarget component is present).

**Golden Master Tests:** Record the behavior of the AI in a known-good
run (the "golden" run) and use it as a reference. This could be as
simple as recording random seed and sequence of decisions. If the BT is
deterministic (same inputs lead to same outputs), then given the same
initial state and random seed, it should always do the same thing. If a
future code change alters that sequence unexpectedly, a test can catch
it. For example, run 100 ticks of an AI and record the sequence of
actions (could be logged to a string like "Idle, Idle, SpotEnemy, Chase,
Attack, Attack..."). Future runs should match that exactly (unless the
change is intentional, in which case update the golden file). Be
careful: if your AI includes any non-determinism (true randomness
without fixed seed, or timing differences), you need to control those
for tests (set a fixed seed, simulate at fixed time steps, etc.).

**Deterministic Timing and RNG:** To have reproducible behavior, ensure
your BT doesn't depend on wall-clock or frame time in an uncontrolled
way. Use a fixed delta time in tests (or even quantize time in game if
you need lockstep). If using random choices in BT (like a random
selector or a noise to vary path), use a *seeded RNG per entity*. For
example, give each AI a RandomState component (e.g. an LCG or XORShift
state) and when a node needs a random number, use and update that
state[[\[39\]]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/#:~:text=Math%20for%20Game%20Programmers%20,Noise%20Based%20RNG).
This way, you can reset that component to a known value to reproduce
randomness. Unity's DOTS has a Random struct that is job-safe and uses a
seed; you can store one per entity.

**Fuzz Testing:** Introduce random perturbations in blackboard inputs to
see if the BT ever gets stuck or crashes. For example, randomize an
agent's hunger, ammo, enemy distance, etc., then tick the BT a few times
and assert it still behaves reasonably (doesn't produce invalid states,
doesn't exceed some loop count, etc.). This can catch edge cases like
division by zero in nodes, or assumptions that don't hold (maybe a node
assumed there is a target when there isn't).

**Property-Based Testing:** Identify invariants in your AI behavior and
test that they hold. Invariants could be: An agent should never attack
when its health is 0 (dead). Or if two agents are allies, they should
never both choose conflicting behaviors (like both trying to heal each
other infinitely). Encode these as assertions in test scenarios. For
ECS, you could simulate multiple entities together to test group
behaviors (like make sure formation holding logic works with 5 agents).
Use the ECS to your advantage: spin up many entities with random initial
states and check invariants after running BTs for a few ticks.

**Regression Tests for Bug Fixes:** When a bug is found (e.g. AI gets
stuck circling, or never transitions out of a state), try to reproduce
it in a deterministic test and then keep that test to ensure it doesn't
come back. For instance, if AI got stuck because two conditions were
toggling each other (like a flicker between two selectors every frame),
write a test where you simulate those condition values oscillating and
verify the BT eventually stabilizes or does something appropriate (maybe
a decorator was needed to add a cooldown; your test can confirm the fix
works by simulating exactly the edge condition).

**Simulation Harness:** Build a headless mode where you can run the game
logic at fast speed for many ticks and examine outcomes. For example,
simulate 1000 frames of an encounter and then evaluate metrics: did all
agents eventually either die or go back to idle? Or are some stuck in an
unnatural state? You could automatically detect "stuck" agents by
checking if an agent has been in the same action for an unrealistic
duration (like an "OpenDoor" node running for 60 seconds). If so, flag
it -- maybe a bug or scenario that needs addressing.

**Multiplayer Determinism and Rollback:** If your AI runs in a networked
game with lockstep or rollback (like an RTS or a fighting game),
determinism is paramount. All the tips above (fixed update, seeded RNG,
no reliance on external state like system time) apply. Additionally,
test that given the exact same sequence of player inputs, two instances
of the game produce the same AI behavior. If they diverge, something
nondeterministic is in play. Rollback (e.g. in a fighting game,
rewinding state for lag correction) means your AI logic should be pure
or at least rewindable. The easiest way to support rollback is to ensure
all AI state is part of the ECS state (components) and thus captured in
the snapshots. Do not keep hidden static variables or rely on
unpredictable order of entity processing (which in ECS is typically
deterministic by archetype order, but if you rely on something like
pointer addresses, that's bad). Write tests that simulate a rollback:
apply some AI updates, then rollback the world state by reloading a
previous snapshot of components, then run again and see if the AI makes
the same decisions. If not, you might be missing something in the
snapshot (like a random generator state or a node's running status).

**Example: Testing a Patrol Behavior:** Suppose an AI should patrol
waypoints until it sees an enemy, then chase. A test could set up an AI
with waypoints and no enemy, run the game for 10 seconds and assert the
AI's position cycles through those waypoints (within some tolerance).
Then introduce an enemy at second 10 and ensure the AI's state changes
to chasing within a frame or two. And if the enemy is removed, does it
go back to patrol after some time? By automating this, you catch if a
refactoring accidentally broke the reactivation of patrol after combat.

**Tooling for Testing:** It can help to build debug commands to
manipulate AI. For instance, a console command to force all AIs into a
certain state, or to dump the state of a particular AI. This can be used
in automated tests or during playtesting. In ECS, you can implement a
test system that listens for a debug event (like a keypress or network
command) and then, for example, adds a component
ForceState{state=Patrol} to entities, which your BT system respects by
transitioning the BT (maybe via a special high-priority node that checks
ForceState). This way, you can reliably put an AI in any node for
testing.

**Continuous Testing:** If you have a large game, consider running an
automated bot that plays the game (or a certain level) for hours and
collects AI stats or catches crashes. ECS's determinism helps here --
you can simulate faster than real-time if no rendering. Some devs run AI
overnight to see if any performance issues (like memory leaks or
slowdowns) occur after long usage. Also observe emergent behavior: ECS
BTs can sometimes lead to unintended oscillations or trivial behaviors
(like all agents doing the same thing in lockstep because they have
similar inputs). Testing at scale (many agents) can reveal these
patterns -- e.g. do 50 agents coordinate or do they all try to occupy
the same spot? If the latter, maybe the BT needs a "yield if spot taken"
node. Write tests with multiple agents to address that.

**Edge Cases:** Test extremes: AI with maxed stats, or no ammo, or
multiple targets, etc. ECS makes it easy to set extreme component values
and see how BT responds. For determinism, also test on different
hardware if possible (floating-point determinism can be an issue across
platforms -- if you need lockstep across machines, use deterministic
math libraries or fixed-point for critical decisions).

In conclusion, treat your ECS-based AI like any other system in terms of
testing: isolate pieces to unit test, simulate whole scenarios for
integration test, and enforce determinism if the game demands it. ECS's
predictable data and the ability to create separate Worlds for testing
(in Unity DOTS you can spin up a World in edit mode, run systems
manually) give you flexibility to run AI logic in non-game contexts
(like headless simulation or batch tests). By investing in good testing,
you'll catch issues early and have confidence when refactoring or adding
new behaviors that you haven't broken existing AI logic.

Architecture Choices: Decision Matrix (Pros and Cons)

Finally, let's summarize the key architecture decisions in implementing
Behavior Trees in ECS, comparing options with their pros and cons:

- **Behavior Tree Representation:**  
  > **Data-Driven (Asset/Blob)** -- *Pros:* Designers can edit without
  > code, supports live tuning and serialization, one asset can be
  > reused by many entities, structure can be inspected at
  > runtime[[\[40\]]{.underline}](https://pixelmatic.github.io/articles/2020/05/13/ecs-and-ai.html#:~:text=Behavior%20Trees%20in%20Unity%20DOTS).
  > *Cons:* Slight overhead to interpret data, harder to ensure type
  > safety (needs robust serialization), changing tree at runtime is
  > non-trivial (need rebuild or version
  > handling)[[\[41\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,and%20created%20by%20BlobBuilder).  
  > **Code-Driven (Hardcoded or Generated)** -- *Pros:* Maximum
  > performance (no runtime dispatch, fully inlined
  > code)[[\[14\]]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html#:~:text=,inline%2C%20and%20do%20other%20magic),
  > compile-time checking of logic, easier to debug in code. *Cons:*
  > Requires recompilation for changes, not designer-friendly, cannot
  > easily serialize/modify at runtime, less flexible (e.g. can't easily
  > data-drive behavior variations).

- **Node Execution Method:**  
  > **Per-Entity Tick (Pull model)** -- *Pros:* Simple mental model,
  > each entity's logic self-contained each frame, priorities naturally
  > re-evaluated each tick. *Cons:* Can waste CPU on waiting behaviors,
  > potentially heavy if many entities tick deep trees every
  > frame[[\[11\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=With%20traditional%20behavior%20tree%20implementations,executed%20if%20the%20status%20changes).  
  > **Event-Driven (Push model with tasks/events)** -- *Pros:* Avoids
  > unnecessary ticking, scales well (idle agents use 0 CPU), fits ECS
  > parallel tasks (each task system
  > optimized)[[\[24\]]{.underline}](https://www.hankruiger.com/posts/bevy-behave/#:~:text=%2F%2F%20the%20next%20step%20would%27ve,).
  > *Cons:* More complex to implement (spawn/despawn overhead, need
  > context linking via something like
  > BehaveCtx[[\[42\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=%2F%2F%20for%20each%20entity%20with,being%20controlled%20by%20the%20behaviour)),
  > debugging across many small entities can be harder, risk of event
  > mis-handling leading to stuck behaviors if not carefully managed.

- **Parallel & Long-running Actions:**  
  > **Within BT (Running state)** -- *Pros:* Simpler BT logic (just
  > return Running and rely on tick loop), no extra entities needed,
  > sequence flow is clear in one place. *Cons:* Every frame overhead to
  > re-check conditions, risk of forgetting to handle interruptions, all
  > logic on single entity context (no multi-entity parallelism).  
  > **Externalize via ECS Systems** -- *Pros:* Leverages ECS efficiency
  > (e.g. one system moves all moving agents) -- effectively multi-agent
  > parallel, can use physics or navmesh systems without BT overhead,
  > easier to maintain complex actions (the code is in a dedicated
  > system not inside BT code). *Cons:* Requires designing a good
  > interface between BT and systems (like components or events as
  > signals), debugging requires tracking state in two places (BT and
  > system).

- **Blackboard Location:**  
  > **On Entity (Components)** -- *Pros:* Ultra-fast access (direct
  > component pointers), no additional lookup
  > needed[[\[6\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,Running%3B),
  > other systems can easily interact (AI and non-AI systems share
  > data), serialization is straightforward. *Cons:* Potentially a lot
  > of components per entity (which could impact chunk size), changes to
  > component schema require code changes (less flexible than a dynamic
  > blackboard).  
  > **Off-Entity (Shared or Separate Storage)** -- *Pros:* Can have
  > dynamic set of variables, easier to share between entities (e.g. a
  > team blackboard), can version independently of ECS components.
  > *Cons:* Access is slower (likely a map lookup or cross-entity
  > reference), not automatically integrated with ECS change detection,
  > more overhead to keep in sync with entity state.

- **Tick Frequency:**  
  > **Every frame (synchronous)** -- *Pros:* Maximal reactivity, simpler
  > timeline (no timing bugs where AI "misses" something because it was
  > asleep), matches traditional game loop expectations. *Cons:* Highest
  > CPU usage, might do redundant checks, doesn't exploit
  > human-perception limits (many decisions don't need 60Hz updates).  
  > **Reduced/variable frequency** -- *Pros:* Huge performance savings
  > if tuned well (most AI can run at lower rate without noticeable
  > difference), allows focusing CPU on most important agents. *Cons:*
  > More complex (need scheduling logic), can introduce latency in
  > responses, difficult to debug time-sliced issues (e.g. if something
  > updates slower, cause/effect spans multiple frames).

- **Threading Model:**  
  > **Single-thread (no jobs)** -- *Pros:* Simpler, no race conditions
  > to worry about within BT, order of operations deterministic, can use
  > game engine API calls directly in nodes. *Cons:* Does not scale to
  > large agent counts, can become a frame bottleneck, under-utilizes
  > multi-core CPUs.  
  > **Multi-thread (jobs for BT)** -- *Pros:* Scales across cores, can
  > handle many entities (especially if workload is evenly
  > distributed)[[\[12\]]{.underline}](http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/#:~:text=Awesome%2C%20and%20thanks%20for%20sharing,a%20lot%20cleaner%20Image%3A),
  > keeps frame times low per core. *Cons:* Requires carefully avoiding
  > data hazards (needs read-only vs write
  > separation[[\[7\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,NodeData),
  > or command buffers), some nodes might be forced to main thread (e.g.
  > ones using engine calls), debugging threaded code is harder
  > (non-deterministic scheduling issues, though if purely data-parallel
  > deterministic, it's okay).

- **Integration with Engine/Framework:**  
  > **Tightly Integrated** -- e.g. using Unity's GameObject hybrid or
  > Unreal's AI system as part of ECS. *Pros:* Leverage existing tools
  > (navigation, perception, etc.) out of the box, perhaps quicker to
  > get working. *Cons:* May break ECS principles (e.g. calling into OOP
  > systems could incur overhead or require sync points), might not
  > scale to ECS's potential, and adds complexity of two paradigms.  
  > **Pure ECS Implementation** -- *Pros:* Consistent with ECS design
  > (data-oriented, no hidden state), likely highest performance if done
  > right, easier to reason about in ECS context (no unexpected
  > interactions with OOP behaviors). *Cons:* Need to implement a lot
  > from scratch or adapt (e.g. custom pathfinding or use ECS-compatible
  > libs), features like built-in BT editors or Blackboards must be
  > re-created or heavily adapted (more initial dev effort).

Each of these choices can be mixed to a degree; for instance, one might
use data-driven BT assets (for flexibility) but still code some critical
parts (for performance), use event-driven tasks for movement but tick
other parts each frame, etc. The **best architecture often hybridizes**
to get benefits of each approach where appropriate. Below is a quick
reference **checklist** of do's and don'ts summarizing the best
practices we've discussed:

Best Practices Checklist for ECS Behavior Trees

- **✅ Do** define your BT structure in a data-oriented way (flat arrays
  > or blobs) for cache
  > efficiency[[\[3\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,with%20Unity%20GameObject%20without%20entity).
  > **Avoid** linked pointer-based node structures at runtime.

- **✅ Do** preallocate and pool memory for BT state (node statuses,
  > etc.) so that ticking does not allocate
  > memory[[\[5\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync).
  > **Avoid** any per-frame GC or malloc in the BT loop.

- **✅ Do** separate pure logic from side effects: let condition nodes
  > *only read* data, and action nodes *either perform minimal writes or
  > just send commands/events*. This makes it easier to parallelize and
  > reason about.

- **✅ Do** utilize ECS systems for heavy lifting. If many agents
  > perform the same kind of action, implement that action as an ECS
  > system processing a component (spawned by the BT) rather than unique
  > code in each BT
  > tick[[\[1\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned).

- **✅ Do** implement event-driven mechanisms for long waits or
  > multi-frame actions (use Running state or spawn tasks) to avoid
  > busy-waiting in the
  > BT[[\[24\]]{.underline}](https://www.hankruiger.com/posts/bevy-behave/#:~:text=%2F%2F%20the%20next%20step%20would%27ve,).

- **✅ Do** use blackboard components for shared data needs and update
  > them with dedicated systems (e.g. a Sight system updates
  > "EnemyVisible" component). This keeps the BT nodes simple and data
  > fresh.

- **✅ Do** group AI updates logically (sense before think before act).
  > Maintain a predictable update order to avoid race conditions (e.g.,
  > don't have one system moving agents before another decides their
  > movement).

- **✅ Do** design for multithreading from the start: mark nodes with
  > read/write intentions, use thread-safe patterns (e.g. no static
  > mutable state), and test with jobs enabled. Where necessary, use
  > main-thread-only tags (like Unity's RunOnMainThread decorator in
  > EntitiesBT for nodes that need
  > it[[\[8\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,once%20meet%20decorator%20of%20RunOnMainThread)).

- **✅ Do** throttle AI updates when possible: lower frequency or LOD
  > for far-away or less important agents. This is often the key to
  > scaling up. As a corollary, **❌ don't** unnecessarily tick AI that
  > have nothing to do (idle NPC in an empty room) -- consider putting
  > them to sleep until needed.

- **✅ Do** instrument your BT system with debug info: even if it's
  > compiled out in shipping, have the ability to log or visualize
  > current node for an
  > entity[[\[10\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync),
  > to greatly ease debugging complex behaviors.

- **✅ Do** test determinism by running the same scenario multiple times
  > -- especially if you plan to use rollback or lockstep. Fix any
  > sources of nondeterminism (unseeded randomness, iteration over hash
  > maps, etc.).

- **✅ Do** validate invariants at runtime in debug mode (e.g. add
  > assertions if a certain component must exist when a node runs, or if
  > a pointer must not be null). In ECS, this can be done by checks
  > inside systems or using debug systems that run and verify world
  > state.

- **❌ Don't** do heavy computations inside a single BT tick for one
  > entity if you can help it -- spread it out. For example, **don't**
  > loop over 1000 entities inside one node to find a target; instead,
  > use an ECS query outside the BT or maintain a spatial index.

- **❌ Don't** let a Running node stall forever without a timeout or
  > re-evaluation path. Always have conditions or failsafes to break out
  > of long waits (e.g. a "Timeout" decorator can turn a long Running
  > into a fail after X seconds, so the BT can try something
  > else)[[\[43\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=).

- **❌ Don't** modify ECS structure (add/remove entities or components)
  > in the middle of ticking an entity's BT without using proper
  > buffering. Structural changes can invalidate iterators or cause sync
  > points -- use command buffers or defer them to after the main tick.

- **❌ Don't** rely on global singletons or static data in your BT logic
  > unless absolutely necessary (and if so, treat them as read-only).
  > They break encapsulation and can become bottlenecks or points of
  > failure in determinism.

- **❌ Don't** neglect cleanup of state. If your BT allocated or spawned
  > something (like a temporary entity for an action), ensure it gets
  > removed when no longer needed to avoid leaks or phantom behaviors.

By following these guidelines and the detailed exploration above, you
can implement robust, efficient Behavior Trees that fully exploit the
advantages of ECS -- achieving scalable AI that can power large and
complex game worlds.

Example: Simplified ECS Behavior Tree Implementation

To tie everything together, let's walk through a *minimal pseudocode
example* of a BT integrated in ECS. This example is framework-agnostic
pseudocode illustrating a few nodes (Sequence, Selector, Condition,
Action with event) and how they might be implemented:

// Components for an agent  
Component BehaviorTree { asset: BTAssetID, currentNode: NodeID }  
Component Blackboard { health: int, hasTarget: bool, targetPos: Vector3,
position: Vector3 }  
  
// Pseudocode representation of a BT asset (could be in a blob or
JSON)  
BTAsset \"GuardBehavior\":  
Nodes:  
0: Selector \[ children: \[1, 4\] \] // Root: if child0 fails, do
child1  
1: Sequence \[ children: \[2, 3\] \] // Sequence: if health low, flee  
2: Condition \"HealthLow?\" (Blackboard.health \< 30)  
3: Action \"FleeToSafeSpot\" (triggers MoveTask to safe position)  
4: Sequence \[ children: \[5, 6\] \] // If not low health, engage
enemy  
5: Condition \"HasTarget?\" (Blackboard.hasTarget == true)  
6: Action \"AttackTarget\" (triggers AttackTask on target)  
  
// System to tick behavior trees  
System BehaviorTreeTick:  
for each entity with BehaviorTree bt, Blackboard bb:  
let asset = BTAssets\[bt.asset\] // fetch the BT structure  
status = TickNode(entity, asset, nodeID=0, bb) // start from root (0)  
// We ignore the returned status here, but could use it for something
(e.g., if tree finished)  
  
Function TickNode(entity, asset, nodeID, bb):  
node = asset.Nodes\[nodeID\]  
switch node.type:  
case \"Selector\":  
// Try children in order until one succeeds  
for childID in node.children:  
status = TickNode(entity, asset, childID, bb)  
if status == Success:  
return Success  
if status == Running:  
return Running  
// if Failure, continue to next child  
return Failure // all children failed  
  
case \"Sequence\":  
// Execute children in order until one fails or is running  
for childID in node.children:  
status = TickNode(entity, asset, childID, bb)  
if status == Failure:  
return Failure  
if status == Running:  
return Running  
// if Success, move to next child  
return Success // all children succeeded  
  
case \"Condition\":  
// Evaluate condition on blackboard  
condFn = node.func // e.g., lambda or pointer set up for condition  
return condFn(bb) ? Success : Failure  
  
case \"Action\":  
// Perform action -- possibly spawning a task or doing a one-frame
effect  
actionName = node.name  
if actionName == \"FleeToSafeSpot\":  
// This action will initiate a movement task if not already running  
if not HasComponent(entity, MoveTask):  
// find a safe spot (for simplicity, predefined or relative to
position)  
safePos = FindCoverNear(bb.position)  
AddComponent(entity, MoveTask{ destination: safePos })  
// Always return Running while move is ongoing  
// Check if reached destination (this check could also be in
MoveSystem)  
if Distance(bb.position, safePos) \< 1.0:  
RemoveComponent(entity, MoveTask)  
return Success  
else:  
return Running  
  
if actionName == \"AttackTarget\":  
if not HasComponent(entity, AttackTask):  
if bb.hasTarget:  
AddComponent(entity, AttackTask{ targetPos: bb.targetPos })  
else:  
return Failure // no target, action fails  
// Simulate attack progress (could be instant or multi-frame)  
// Here, we\'ll assume an instant attack that completes immediately for
demo  
// In a real scenario, you might set Running until an animation
finishes, etc.  
if bb.hasTarget:  
// Apply damage to target via an event or direct (assuming direct here
for simplicity)  
DealDamageToClosestTarget(bb.targetPos)  
RemoveComponent(entity, AttackTask)  
return Success  
else:  
RemoveComponent(entity, AttackTask)  
return Failure  
  
// Other actions\...  
return Success // default  
  
default:  
return Failure // unknown node type

In this pseudocode:

- We defined a simple guard behavior with two high-level branches: if
  > health is low, flee; otherwise if there's a target, attack. The root
  > is a Selector node (node 0) that chooses between fleeing (node1) and
  > engaging (node4). Node1 and node4 are Sequence nodes representing
  > ordered steps.

- The BehaviorTreeTick system iterates through entities with a
  > BehaviorTree and Blackboard and calls TickNode on the root. The
  > TickNode function handles Selector and Sequence logic, as well as
  > conditions and actions.

- Condition nodes (like \"HealthLow?\" and \"HasTarget?\") directly read
  > the Blackboard component (here simplified as direct field access
  > checks) and return Success/Failure.

- Action nodes (\"FleeToSafeSpot\" and \"AttackTarget\") demonstrate how
  > to use ECS components for tasks:

- **FleeToSafeSpot:** We check if the entity already has a MoveTask
  > component. If not, we add one with a destination (using a
  > hypothetical FindCoverNear function). Then we return Running until
  > the entity's position is near the safe spot, at which point we
  > remove the MoveTask and return Success. Meanwhile, presumably a
  > MoveSystem is running elsewhere that processes MoveTask components
  > by moving the entity a bit each frame (updating
  > Blackboard.position). This separation means the heavy lifting
  > (movement integration, pathfinding perhaps) is done outside the BT.

- **AttackTarget:** Similar idea with an AttackTask. We add it if not
  > present (maybe starting an attack animation or cooldown). In this
  > simple example, we immediately apply damage and consider it success.
  > In a real scenario, you could set it Running while an animation
  > plays, and some AnimationSystem or AttackSystem would mark it done
  > (or the BT could check a timer or animation flag in the blackboard).
  > We also handle the case of no target (fail immediately).

- We use AddComponent/RemoveComponent to interface with ECS world (these
  > would be queued in a command buffer in a real multi-threaded
  > context, or done directly if safe). By adding MoveTask or
  > AttackTask, we let other systems handle movement or combat. The BT
  > monitors the progress via blackboard (position updates, etc.). This
  > illustrates *deferred action completion*.

- The BT is largely data-driven (the structure in BTAsset), but node
  > logic is in code (the pseudocode inside TickNode). In a data-only
  > approach, you might not use a switch but instead have node types
  > stored and call pre-registered function pointers. But the outcome is
  > similar.

- Note the *Running vs Success/Failure* flow: The Sequence and Selector
  > logic will propagate Running upward. So if FleeToSafeSpot returns
  > Running, the Sequence (node1) returns Running, and then Selector
  > (node0) will return Running as well -- meaning the tree is not
  > finished this tick and should be called again next frame (or
  > whenever). If an action completes or fails, the logic handles that
  > and higher nodes react accordingly.

- Also note how an entity's Blackboard.hasTarget is used as a condition.
  > We would have some system or logic outside (maybe a VisionSystem)
  > that sets hasTarget=true and targetPos when an enemy is spotted, and
  > unsets it when not. That event would naturally cause the BT
  > condition to succeed and move into attack. If the target disappears,
  > next tick HasTarget? would fail and the Selector would cause the
  > whole engage branch to fail, falling back (perhaps to idle patrol if
  > that was another branch not shown).

This pseudocode is simplified (e.g., we didn't implement a Wait or
Parallel node), but it shows how an ECS BT can operate: - Each node type
does minimal work and often interacts with ECS by adding/removing or
checking components. - Long running actions are handled by setting
components and returning Running, letting other systems do the work. -
The tree traversal uses function calls (could be turned into an
iterative loop with an explicit stack if deep recursion is a worry). -
Blackboard is just a component struct, making access straightforward and
fast.

In a real implementation, you'd flesh out more node types (e.g.
Decorators like Inverter or Cooldown). For instance, a Cooldown
decorator could wrap an action node and use a LastTime stored in the
blackboard to ensure a minimum time between successes. This would fit in
by checking time in TickNode before executing the child.

The *separation of concerns* is key: BT for high-level decision/order of
actions, ECS components/systems for execution of those actions. This
keeps the BT logic clean and the ECS systems optimized. It also means
multiple agents can share systems (all moving entities handled together,
all attacking ones together), which is exactly what ECS is good at.

By following this structure and the guidance throughout the document,
you can implement behavior trees in a manner that is scalable,
maintainable, and performant, while also being adaptable across
different ECS-based game engines or frameworks.

**Sources:**

- Ray Tang, *\"What AI for Unity DOTS\"* -- discusses adapting AI
  > techniques (FSM, BT, Utility AI) to Unity's ECS, recommending a
  > DOTS-native BT
  > example[[\[40\]]{.underline}](https://pixelmatic.github.io/articles/2020/05/13/ecs-and-ai.html#:~:text=Behavior%20Trees%20in%20Unity%20DOTS).

- **EntitiesBT** (Quabug's Unity ECS Behavior Tree): Open-source
  > framework showing data-oriented BT with blob storage, thread
  > control, and variant blackboard system[[\[44\]]{.underline}
  > HYPERLINK
  > \"https://github.com/quabug/EntitiesBT#:\~:text=,once%20meet%20decorator%20of%20RunOnMainThread\"[\[8\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,tree%20into%20a%20binary%20file).

- Richard Jones, *Bevy Behave* (Rust) -- demonstrates spawning entities
  > for BT actions and using events to signal
  > completion[[\[1\]]{.underline} HYPERLINK
  > \"https://www.hankruiger.com/posts/bevy-behave/#:\~:text=%2F%2F%20the%20next%20step%20would%27ve,\"[\[24\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned).

- Opsive, *Behavior Designer Pro* Documentation -- outlines how a
  > DOTS-based BT system avoids full tree re-evaluation via conditional
  > aborts[[\[11\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=With%20traditional%20behavior%20tree%20implementations,executed%20if%20the%20status%20changes)
  > and provides features like blackboard, tasks, and syncing with ECS
  > data[[\[36\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=Behavior%20Designer%20Pro%20is%20the,that%20you%20are%20using%20it).

- Lisyarus Blog, *C++ Behavior Trees design* -- explores template-based
  > compile-time BT construction and highlights performance
  > considerations of contiguous storage and no virtual
  > calls[[\[14\]]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html#:~:text=,inline%2C%20and%20do%20other%20magic).

- Opsive Forum (Justin, 2024) -- mentions targeting "tens or hundreds of
  > thousands" of agents with DOTS BT, emphasizing the scalability of
  > ECS for
  > AI[[\[12\]]{.underline}](http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/#:~:text=Awesome%2C%20and%20thanks%20for%20sharing,a%20lot%20cleaner%20Image%3A).

- Unreal Engine 5 Documentation -- *StateTree* (Mass ECS AI system)
  > which combines BT selectors with state machine concepts for
  > high-performance crowd
  > AI[[\[45\]]{.underline}](https://forums.unrealengine.com/t/understanding-massai-mass-crowd/1623463#:~:text=StateTree%20is%20a%20general,and%20Transitions%20from%20state%20machines).

- Han Kruiger, *\"Modelling Agent Behaviour with Bevy Behave\"* -- blog
  > post illustrating how BT tasks are offloaded to separate entities
  > and systems in Bevy, improving decoupling[[\[2\]]{.underline}
  > HYPERLINK
  > \"https://www.hankruiger.com/posts/bevy-behave/#:\~:text=%2F%2F%20the%20next%20step%20would%27ve,\"[\[24\]]{.underline}](https://www.hankruiger.com/posts/bevy-behave/#:~:text=An%20important%20difference%20between%20Bevy,you%20want%20it%20to%20control).

- EntitiesBT GitHub -- notes features like 0 GC allocations after init
  > and continuous node data blob, plus debug
  > tooling[[\[10\]]{.underline} HYPERLINK
  > \"https://github.com/quabug/EntitiesBT#:\~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync\"[\[5\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync).

- Bobby Anguelov et al., *\"AI Arborist: Behavior Trees\"* (GDC 2017) --
  > core BT best practices (visualization, modifier nodes) and
  > performance tips for large projects (as summarized by Sean
  > Middleditch)[[\[46\]]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/#:~:text=This%20talk%20was%20a%20set,tips%20on%20using%20Behavior%20Trees).

[[\[1\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned)
[[\[18\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=match%20at%20L371%20tree%20by,component)
[[\[25\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=match%20at%20L521%20of%20components,mechanism%20to%20generate%20status%20reports)
[[\[31\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=When%20an%20action%20node%20,the%20entity%20will%20be%20despawned)
[[\[42\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=%2F%2F%20for%20each%20entity%20with,being%20controlled%20by%20the%20behaviour)
[[\[43\]]{.underline}](https://github.com/RJ/bevy_behave#:~:text=)
GitHub - RJ/bevy_behave: Behaviour trees for bevy, with on-demand entity
spawning for task nodes.

[[https://github.com/RJ/bevy_behave]{.underline}](https://github.com/RJ/bevy_behave)

[[\[2\]]{.underline}](https://www.hankruiger.com/posts/bevy-behave/#:~:text=An%20important%20difference%20between%20Bevy,you%20want%20it%20to%20control)
[[\[24\]]{.underline}](https://www.hankruiger.com/posts/bevy-behave/#:~:text=%2F%2F%20the%20next%20step%20would%27ve,)
Modelling Agent Behaviour with Bevy Behave \| Han

[[https://www.hankruiger.com/posts/bevy-behave/]{.underline}](https://www.hankruiger.com/posts/bevy-behave/)

[[\[3\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,with%20Unity%20GameObject%20without%20entity)
[[\[4\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=match%20at%20L715%20public%20BlobArray,once%20reset)
[[\[5\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync)
[[\[6\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,Running%3B)
[[\[7\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,NodeData)
[[\[8\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,once%20meet%20decorator%20of%20RunOnMainThread)
[[\[9\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,suspended)
[[\[10\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync)
[[\[16\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=Packages)
[[\[17\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=%5BBehaviorNode%28%22867BFC14,float%3E%20FloatVariant)
[[\[19\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=controlled%20by%20the%20behavior%20tree,allocated%20every%20tick%20by%20CreateArchetypeChunkArrayAsync)
[[\[27\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=compatibility%20of%20other%20plugins.%20,tree%20into%20a%20binary%20file)
[[\[28\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=public%20void%20Reset,)
[[\[29\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,NodeData)
[[\[30\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=public%20NodeState%20Tick,deltaTime.Value)
[[\[32\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=)
[[\[33\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=)
[[\[34\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=)
[[\[35\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=%2F%2F%20most%20important%20part%20of,INodeBlob)
[[\[41\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,and%20created%20by%20BlobBuilder)
[[\[44\]]{.underline}](https://github.com/quabug/EntitiesBT#:~:text=,tree%20into%20a%20binary%20file)
GitHub - quabug/EntitiesBT: Behavior Tree for Unity ECS (DOTS) framework

[[https://github.com/quabug/EntitiesBT]{.underline}](https://github.com/quabug/EntitiesBT)

[[\[11\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=With%20traditional%20behavior%20tree%20implementations,executed%20if%20the%20status%20changes)
[[\[20\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=The%20numeric%20comment%20next%20to,parent%20task%20the%20tree%20ends)
[[\[21\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=This%20tree%20is%20really%20similar,execution%20order%20of%20their%20children)
[[\[22\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=Image)
[[\[26\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/#:~:text=One%20of%20the%20advantages%20of,time%20as%20their%20sibling%20branches)
Flow - Opsive

[[https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/concepts/flow/)

[[\[12\]]{.underline}](http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/#:~:text=Awesome%2C%20and%20thanks%20for%20sharing,a%20lot%20cleaner%20Image%3A)
[[\[37\]]{.underline}](http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/#:~:text=with%20it%20and%20can%20respond)
Using behavior tree to modify Unity ECS entity component data \| Opsive

[[http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/]{.underline}](http://www.opsive.com/forum/index.php?threads/using-behavior-tree-to-modify-unity-ecs-entity-component-data.10696/)

[[\[13\]]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/#:~:text=forward%20efficiently%2C%20and%20may%20have,compelling%20option%20for%20game%20devs)
[[\[39\]]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/#:~:text=Math%20for%20Game%20Programmers%20,Noise%20Based%20RNG)
[[\[46\]]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/#:~:text=This%20talk%20was%20a%20set,tips%20on%20using%20Behavior%20Trees)
My GDC \'17 Talk Retrospective \| Game Development by Sean

[[https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/]{.underline}](https://seanmiddleditch.github.io/my-gdc-17-talk-retrospective/)

[[\[14\]]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html#:~:text=,inline%2C%20and%20do%20other%20magic)
[[\[15\]]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html#:~:text=Amusingly%2C%20it%20actually%20works%21%20The,benefits%20of%20this%20approach%20are)
C++ behavior trees library design \| lisyarus blog

[[https://lisyarus.github.io/blog/posts/behavior-trees.html]{.underline}](https://lisyarus.github.io/blog/posts/behavior-trees.html)

[[\[23\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=,Conditional%20Evaluator)
[[\[36\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=Behavior%20Designer%20Pro%20is%20the,that%20you%20are%20using%20it)
[[\[38\]]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/#:~:text=,48)
Behavior Designer Pro - Opsive

[[https://opsive.com/support/documentation/behavior-designer-pro/]{.underline}](https://opsive.com/support/documentation/behavior-designer-pro/)

[[\[40\]]{.underline}](https://pixelmatic.github.io/articles/2020/05/13/ecs-and-ai.html#:~:text=Behavior%20Trees%20in%20Unity%20DOTS)
What AI for Unity DOTS · PxDev

[[https://pixelmatic.github.io/articles/2020/05/13/ecs-and-ai.html]{.underline}](https://pixelmatic.github.io/articles/2020/05/13/ecs-and-ai.html)

[[\[45\]]{.underline}](https://forums.unrealengine.com/t/understanding-massai-mass-crowd/1623463#:~:text=StateTree%20is%20a%20general,and%20Transitions%20from%20state%20machines)
Understanding MassAI & Mass Crowd - Programming & Scripting - Epic
Developer Community Forums

[[https://forums.unrealengine.com/t/understanding-massai-mass-crowd/1623463]{.underline}](https://forums.unrealengine.com/t/understanding-massai-mass-crowd/1623463)
