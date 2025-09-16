# Finite State Machines in ECS: Patterns and Best Practices

Finite State Machines (FSMs) can be implemented in an
Entity-Component-System (ECS) architecture using several architectural
patterns. Unlike an OOP FSM (with state classes and polymorphic
methods), an ECS FSM represents **state through data composition**. In
ECS, an entity's active state is often indicated by which components it
has (or doesn't have) at a given
time[\[1\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=However%2C%20everything%20changes%20when%20you,they%20only%20care%20about%20the).
For example, instead of a `RunningState` object, an ECS might mark a
player as \"running\" by adding a **Running component** (possibly
alongside other movement components) to that entity. Switching states
then means changing the entity's components (data), and systems respond
to those components. This data-driven approach poses unique challenges
for managing transitions and organizing state logic without resorting to
monolithic `if/else` blocks in
systems[\[2\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=The%20best%20way%20,conditions%20to%20transition%20between%20states).

Below we break down the dominant FSM patterns in ECS in a
**framework-agnostic** way. We cover how each pattern works, how state
transitions are handled, and how state data is stored, with practical
examples from gameplay (AI behavior, player movement states), animation
state machines, and UI flow control. We then compare these approaches in
terms of performance, modularity, readability, debugging, and
suitability for different use cases.

## Component-per-State (Tag Components for States)

One common ECS pattern is to represent each possible state as a
**separate component type**, often a tag or marker component (an empty
or simple data component). An entity is "in" a state if and only if it
has the corresponding state component. For example, an AI enemy could
have components `Patrolling` or `Chasing` to denote its behavior state,
or a UI menu entity could have `Visible` vs `Hidden` state components.
Only one of these mutually exclusive state components is present at a
time on the entity.

- **Implementation:** Define a component for each state (possibly with
  no data if only used as a flag). Attach the component corresponding to
  the current state onto the entity, and remove it when leaving that
  state[\[3\]](https://github.com/skypjack/entt/discussions/1230#:~:text=It%20doesn%27t%20depend%20on%20EnTT,%E2%80%8D%E2%99%82%EF%B8%8F).
  Systems can then naturally filter for entities in a given state by
  querying for that component type. For instance, a `ChaseSystem` might
  run only on entities with the `Chasing` component, and an `IdleSystem`
  on those with the `Idle` component. This clusters entities by state:
  all entities in state X share an archetype/chunk, optimizing
  iteration[\[4\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Group%20entity%20data%20according%20to,state%20data%20clustering).

- **State Transitions:** Handled via **structural changes** -- adding or
  removing the state components at runtime. A transition from state A to
  B would typically be done by an ECS system or a special FSM
  controller: e.g. remove `StateA` component and add `StateB`. Some
  implementations provide an explicit FSM manager to do this mapping.
  For example, Richard Lord's Ash ECS provided a `FiniteStateMachine`
  helper that maps states to required component sets and adds/removes
  components on a state change
  call[\[5\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=To%20make%20managing%20the%20state,to%20be%20in%20various%20states)[\[6\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=).
  In a simpler approach, a transition system can directly swap the tag
  components (or one system per state can trigger the next state). The
  key is that only one state-tag component remains after transition,
  enforcing exclusivity.

- **Data Storage:** Any state-specific data can be stored in separate
  components that are present only in that state. For example, an entity
  in a \"Jumping\" state might have a `Jump` component with jump height
  or duration. Those components would be added/removed together as part
  of entering or exiting that state. The state tag itself might carry no
  data (just an empty type to identify the state). This pattern
  naturally groups state-specific data with the state itself -- when the
  entity exits the state, those components get removed
  too[\[7\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=States%20are%20no%20longer%20objects,held%20by%20the)[\[8\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=,held%20by%20the%20entity).
  One must ensure that at most one state tag is present (to avoid
  invalid combined
  states[\[9\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=Problem%20with%20the%20component));
  this can be managed by centralizing state changes in one system or by
  checks when adding state components.

**Use Cases:** Component-per-state works well for **AI behaviors and
player states** where states are distinct and relatively few (idle,
move, attack, etc.), because it allows writing highly modular systems
for each state. For instance, you might have separate systems handling
movement logic when an entity has `Running` versus `Jumping`. This keeps
logic for each state isolated and easy to maintain. It's also suitable
for **animation FSMs**: e.g. add a `AnimationState_Run` component to
trigger running animation, etc., which an AnimationSystem can pick up.
And for **UI flows** with discrete modes (MainMenu, InGame, Paused), you
can attach a state tag to a singleton UI controller entity and have
systems enable/disable UI elements based on which tag is active.

**Advantages:** This pattern yields **clear modularity** -- each state's
behavior can be in its own system that runs only on entities in that
state[\[3\]](https://github.com/skypjack/entt/discussions/1230#:~:text=It%20doesn%27t%20depend%20on%20EnTT,%E2%80%8D%E2%99%82%EF%B8%8F).
It also aligns with ECS data-oriented principles: entities in the same
state are tightly grouped in memory, so systems process them efficiently
without
branching[\[4\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Group%20entity%20data%20according%20to,state%20data%20clustering).
Debugging is straightforward since an entity's current state is visible
as a component in its data (easy to inspect).

**Trade-offs:** The downside is that **state changes cause structural
changes** (adding/removing components), which can be costly if they
happen very frequently or in
bulk[\[10\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,to%20query%20update%20and%20execution).
Frequent state toggling can lead to performance overhead from archetype
churn and memory moves. Additionally, if there are many possible states,
this approach can explode the number of archetypes and small chunks,
causing **data fragmentation** (many sparse chunks with few
entities)[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk).
This hurts cache coherence if most chunks are half-empty or if queries
have to consider many archetypes. Care should be taken that the number
of states is reasonable. Unity DOTS guidance suggests limiting the
states that use separate archetypes -- too many can increase overhead in
scheduling and chunk
management[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk).
Another consideration is ensuring exclusivity: the system responsible
for transitions must prevent two state components from coexisting on one
entity (which could otherwise happen if transitions are not atomic).
Some ECS frameworks or patterns introduce a higher-level **state machine
component** to manage these transitions more safely (discussed later).

To mitigate structural cost, a variation of this pattern is using
**Enable/Disable on state components** instead of add/remove, if the ECS
supports it. For example, in Unity Entities, you can mark a component
type as *enableable*, and then toggle its enabled bit per
entity[\[12\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,iterate%20over%20entities%20and%20check).
This lets you "activate" or "deactivate" a state on an entity without a
full structural change (disabled components are ignored by queries). It
achieves a similar effect as removing the component (entities with it
disabled won't match state-specific queries), but can skip the cost of
rearranging archetypes on each
toggle[\[12\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,iterate%20over%20entities%20and%20check).
The trade-off here is internal complexity and still needing to ensure
only one state's component is enabled at a time. If implemented
properly, enabling/disabling can skip entire chunks of entities that are
in inactive states, improving performance when many entities are in an
\"off\"
state[\[12\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,iterate%20over%20entities%20and%20check).

## Single-Component FSM (State ID in Component)

Another approach is to condense the FSM into a **single component** that
holds a *state identifier* (e.g. an enum or integer representing the
current state) and possibly additional data for the FSM. Rather than
adding/removing components for each state, the entity always has this
one FSM component; the component's data changes to reflect state
transitions.

- **Implementation:** Define an `FSMComponent` (or specific name, e.g.
  `PlayerState` component) that contains a field for `CurrentState`
  (enum or ID) and any shared FSM context data. Each entity that needs
  an FSM gets this component. A generic **FSM System** (or a small set
  of systems) then processes all entities with an `FSMComponent`, using
  the state field to decide what to do. This usually means an internal
  switch or branching on the state value for each
  entity[\[13\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Keep%20entities%20with%20different%20states,states%20in%20a%20single%20job).
  For example, a single `StateUpdateSystem` might run a
  `switch(entity.State.CurrentState)` and execute state-specific logic
  or call state-specific functions. Alternatively, you can have multiple
  systems that each filter by a particular state value, but since
  standard ECS queries can't filter by a component's internal data
  without special support, this typically falls back to runtime checks
  (unless using something like a shared component or separate archetypes
  per state, which brings us back to the previous approach).

- **State Transitions:** Handled by **updating the state field** within
  the component (no structural change). For instance, when input or AI
  logic dictates a state change, a system will set
  `fsm.CurrentState = State::Running` (perhaps also resetting timers or
  other data as needed). Because this is just a data write, it's very
  fast and can happen frequently with minimal overhead (no moving
  entities between chunks). However, the logic to determine *when* to
  change the state must live in some system. You can either have a
  monolithic FSM system that both checks conditions and updates the
  state (perhaps by consulting other components like input or AI
  sensors), or split that responsibility: e.g. an **InputSystem** might
  check input and decide to change the FSM component's state, and an
  **FSMTransitionSystem** applies the change. The key is that
  transitions are explicit assignments to the state variable rather than
  adding/removing
  components[\[14\]](https://github.com/skypjack/entt/discussions/1230#:~:text=One%20way%20to%20do%20that,%E2%80%8D%E2%99%82%EF%B8%8F).

- **Data Storage:** Since the entity doesn't lose or gain components
  across states, any data specific to a given state must either be
  encapsulated in the FSM component (with fields or sub-structures for
  each state's info) or exist in always-present components that are
  conditionally used. For example, you might have a generic
  `AnimationData` component that covers all possible animation states,
  and the FSM state ID picks which subset of that data is relevant.
  Another option is to combine this approach with the
  component-per-state approach by still attaching additional components
  for data when needed, even if the main state machine is tracked by an
  enum. However, typically the single-component FSM pattern implies most
  state-specific context is contained in that component or in the FSM
  system's logic. This keeps all FSM logic and data in one place, but
  can reduce the advantages of ECS separation if not managed carefully.

**Use Cases:** A single-component FSM is essentially an **embedded state
machine** per entity. This approach can make sense if each entity's FSM
is fairly self-contained or if you want to avoid the overhead of
structural changes. For example, a **player character** with a handful
of states might use a `PlayerState` component with an enum
(Idle/Run/Jump/etc.) and a unified system to handle transitions and
behaviors. Because there's usually only one player, performance is not
an issue and having the logic in one system is manageable. This pattern
is also common for **global state machines** (like a game mode manager):
you might have a singleton entity with a `GameState` component (enum for
Menu, Playing, Paused, etc.) and a system that branches on that to
enable/disable the appropriate aspects of the game. In ECS frameworks
that encourage minimal structural changes (to maximize cache stability),
the data-driven approach is attractive.

**Advantages:** The biggest benefit is **avoiding structural changes**
on each state transition. Changing an integer or enum field is extremely
cheap, so this can handle rapid or numerous transitions
smoothly[\[15\]](https://www.reddit.com/r/gamedev/comments/i7pkj3/why_storing_state_machines_in_ecs_is_a_bad_idea/#:~:text=Good%20question%21%20The%20states%20are,rewiring%20of%20the%20linked%20lists).
There's no archetype explosion from many states since the component is
always present (all these entities remain in one archetype). This can be
more cache-friendly if entities frequently flip states, as you're not
constantly moving them between chunks. Another benefit is simplicity:
you have one component and one authoritative place (system) managing the
state logic, which can be easier to debug step-by-step, as everything is
in one flow of code (no jumping between systems per state). It also
inherently prevents multiple states at once -- the state field can hold
only one value at a
time[\[15\]](https://www.reddit.com/r/gamedev/comments/i7pkj3/why_storing_state_machines_in_ecs_is_a_bad_idea/#:~:text=Good%20question%21%20The%20states%20are,rewiring%20of%20the%20linked%20lists).

**Trade-offs:** The downsides relate to code structure and data-oriented
design. A single system with a big switch or branching logic for each
state **reduces modularity** -- you effectively have a giant function
handling all states, which can become unwieldy as the FSM grows. It's
harder to **extend** (adding a new state means modifying the central
system's code) compared to adding a new component + system in the
component-per-state approach. **Performance-wise**, while you avoid
structural costs, you introduce per-entity branching. If you have many
entities with different states, an `FSMSystem` might iterate over all of
them and perform a check for each possible state, skipping most. This
can lead to *unneeded data fetching*: you pull in data for entities even
if they aren't in the branch of
interest[\[16\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=For%20more%20information%2C%20refer%20to,This%20also%20increases%20cache%20misses).
For example, if 90% of entities are Idle and 10% Running, a single
system branching on state will still touch all 100% entities for both
Idle and Running logic checks, whereas separate state-specific systems
would naturally skip 90% in one and 10% in the other. In other words,
you lose some cache efficiency by not clustering states. Unity's ECS
documentation notes that iterating and skipping entities in undesired
states means fetching more cache lines than
necessary[\[16\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=For%20more%20information%2C%20refer%20to,This%20also%20increases%20cache%20misses),
and iterating the same chunk multiple times (if you manually split it
per state) adds
overhead[\[17\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=having%20all%20entities%20in%20the,This%20also%20increases%20cache%20misses).
Another con is **readability**: the logic for each state might be
intermixed in one place. However, this can be mitigated by delegating to
state-specific functions or using a strategy pattern internally.

Finally, storing state-specific data inside one component can become
messy. If states have vastly different needs, the component may carry a
superset of all possible state data (many fields maybe unused in some
states), or use unions. This is less clean than having separate
components, but is sometimes acceptable if data overlap is high. In
summary, single-component FSMs favor runtime efficiency for frequent
transitions and simplicity for small FSMs, at the cost of code
organization and potential data overhead.

## Component-Based State Machines with Transition Systems

This pattern is a refinement of the component-per-state approach that
introduces a **dedicated FSM controller** (often as another component or
system) to manage state transitions declaratively. The idea is to still
use state components to represent the active state, but avoid littering
the transition logic across many systems or big `if/else` blocks.
Instead, a **state machine component** or manager object keeps a table
of allowed transitions (the FSM graph) and performs the component swaps
when triggers occur.

- **Implementation:** Each entity that needs an FSM gets both the state
  tag components (for the current state) *and* an FSM controller
  component. For example, using the earlier AI scenario, an entity might
  initially have `Patrolling` plus a generic `FSM` component. The FSM
  component could contain a list or map of transitions: e.g. when in
  Patrolling, if "player spotted" trigger fires, transition to Chasing
  state, etc. There may also be global or shared systems that produce
  triggers (like a system that detects player proximity and signals the
  FSM). A concrete example is the **Seldom State** plugin for Bevy ECS,
  which lets you attach a `StateMachine` component and define
  transitions in code. In Seldom's model, *states are still components*
  (e.g. `Jumping` or `Stunned` structs), and the StateMachine component
  holds the list of transitions and optional enter/exit
  callbacks[\[18\]](https://github.com/Seldom-SE/seldom_state#:~:text=%60seldom_state%60%20is%20a%20component,components%20directly%20in%20your%20systems)[\[19\]](https://github.com/Seldom-SE/seldom_state#:~:text=and%20one%20to%20transition%20to%3B,state%20according%20to%20those%20transitions).
  At runtime, the StateMachine system automatically **adds or removes
  the state components** according to the defined transitions and
  triggers[\[20\]](https://github.com/Seldom-SE/seldom_state#:~:text=A%20state%20is%20a%20component,state%20according%20to%20those%20transitions).

- **State Transitions:** Handled by the FSM component/system
  *dynamically*. For instance, a StateMachine might be configured such
  that "From *any state*, if health \<= 0, transition to Dead state."
  When a trigger condition is met, the FSM logic will remove the old
  state component and insert the new state component on the entity (and
  perhaps also add/remove a bundle of other components if specified for
  entering/exiting that state). This approach often includes support for
  **OnEnter/OnExit hooks** -- i.e. executing certain actions or adding
  additional components on state
  entry/exit[\[21\]](https://github.com/Seldom-SE/seldom_state#:~:text=MyInitialState%3A%3Anew%28%29%2C%20StateMachine%3A%3Adefault%28%29%20.trans%3A%3A,MyBundle).
  In Ash (an older ECS framework), the FiniteStateMachine class was used
  exactly this way: you register for an entity which components make up
  each state, and calling `ChangeState("StateName")` would automatically
  add/remove the components to match that
  state[\[22\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=fsm.CreateState%28)[\[6\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=).
  Because transitions are specified in a data-driven way, the actual
  system code handling them is generic and does not need hard-coded
  branches for specific states. Essentially, the FSM component acts as a
  **lookup table** for state configurations and valid transitions, and
  the ECS simply applies those changes.

- **Data Storage:** The state representation is still primarily the
  presence of particular components. The FSM controller might hold
  minimal data (like the current state name or ID for reference, and the
  transition rules). Any extended state-specific data remains in the
  state components or other regular components that get toggled. For
  instance, if entering a "PoweredUp" state should increase an entity's
  speed, the FSM could add a `PowerUp` component or modify a stat
  component on enter. These changes are orchestrated by the FSM system
  but stored in normal components. This pattern centralizes *when and
  how* components are switched, but the actual gameplay data lives in
  those components.

**Use Cases:** This is very useful for **complex AI** or character state
machines where transitions have multiple conditions and you want to
avoid writing those conditions in many places. By encoding transitions
in one place (the FSM configuration), you improve maintainability -- you
can see the whole state graph easily. It's also beneficial for
**reusability**: you might have a standard FSM for "enemy behavior" that
you can attach to many enemy entities, rather than custom code per enemy
type. The FSM component approach is framework-agnostic (the concept can
be implemented in Unity ECS, Bevy, EnTT, etc.) and often libraries or
engine tooling exist to help define these state machines. For example,
Unity's traditional MonoBehaviour world has an Animator controller for
animation FSMs; in ECS one could similarly create a data-driven
animation FSM. For **animation systems**, a state machine component
could hold an animation graph and manage enabling the right animation
playback components on an entity (like switching which AnimationClip
component is active). For **UI flows**, you could use a state machine
component on a UI manager entity that lists transitions between UI
screens on certain events (button clicked -\> go to next menu, etc.),
enabling/disabling UI entities accordingly.

**Advantages:** This pattern provides a **structured and declarative
way** to handle states. It helps avoid the "spaghetti" of scattered
if-else checks in multiple systems by concentrating transition logic. As
one developer observed, using a manager that maps component compositions
to state identifiers avoids lengthy switch statements in
systems[\[23\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=In%20more%20naive%20approaches%20to,a%20member%20of%20a%20system).
Each state's behavior can still be processed by distinct systems (since
state tags are present), but the *switching* is handled in one place,
which tends to be more maintainable. It also cleanly handles mutual
exclusion of states -- the FSM system ensures only the correct
components for the target state are present, so you don't get an entity
stuck with an invalid mix. For debugging, this can be great: you can
often query the FSM component to see what state it thinks the entity is
in, and have confidence the components match that.

**Trade-offs:** There is some overhead in flexibility. Using an FSM
controller adds another layer of indirection -- instead of simply
toggling a component in game code, you might fire a trigger and rely on
the FSM system to do it next frame. This could introduce slight
complexity in debugging the exact moment of transition.
Performance-wise, this approach still often uses structural changes
under the hood (since it's fundamentally adding/removing components on
transitions), so it inherits the costs discussed for the
component-per-state pattern. You need to be mindful of too many
transitions per frame or a huge number of states causing archetype
fragmentation[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk).
The declarative setup can also be more complex to initial developers
than straightforward branching code. Additionally, an FSM system might
end up iterating over all entities with an FSM component each frame to
check triggers (unless using events), which is an extra loop --- though
typically the cost is not high if the checks are simple, or if using
event-driven triggers. In summary, component-based FSM with a transition
system is powerful for complex state logic and reuse, but adds a bit of
upfront complexity and still must manage the underlying data
efficiently.

## State as an Entity (State-Entity Pattern)

An unconventional but effective pattern in ECS is to externalize states
into separate **state entities**. In this approach, the *current state*
of an entity is represented by another entity (or set of entities)
rather than by components on the main entity. The primary entity (often
called the owner) might have a component that references its current
state entity. Each state entity in turn can have components that define
the behavior or data of that state. When a state transition occurs,
instead of changing components on the owner, you spawn a new state
entity (or activate one) and update the reference.

- **Implementation:** Typically, you have an **Owner entity** (e.g. an
  AI agent) and for each possible state, a prefab or archetype for a
  corresponding **State entity**. A state entity might have a tag
  component identifying which state it represents (like
  `ChaseStateTag`), along with any components needed for that state\'s
  logic (timers, target info, etc.). When the owner enters that state,
  you create an instance of that state entity and link it to the owner
  (for example, via an `Owner` reference component on the state). The
  owner might also hold a component like `CurrentStateEntity` to quickly
  look up its state. Systems then operate on the state entities rather
  than directly on the owner for state-specific behavior. For example, a
  `ChaseSystem` could look for all entities with `ChaseStateTag` and
  process them -- each such entity represents an owner currently in
  chasing mode. Through the link, the system can modify the owner (e.g.
  set its velocity toward the
  target)[\[24\]](https://discussions.unity.com/t/any-burst-enabled-dots-state-machines-out-there/948011#:~:text=Engine%20discussions,component%20that%20the%20owner).
  Essentially, you've moved the state out into a child entity that
  carries the state-specific components.

- **State Transitions:** Handled by **spawning or swapping entities**.
  To transition an owner from one state to another, the FSM logic would
  destroy or deactivate the old state entity and create a new one for
  the new state (and update the owner's reference). This can be
  orchestrated by a system that monitors some condition on the owner or
  on the state entity (like a \"state finished\" event). One benefit
  here is that the owner's archetype remains stable -- you are not
  constantly adding/removing components on the owner itself, only
  replacing the linked state entity. The cost of a transition is then
  the creation/destruction of a small entity (the state). This is still
  a structural change, but a localized one. Another benefit is that you
  can easily implement **nested or hierarchical states** by having an
  owner reference multiple state entities (for example, a global state
  and a sub-state simultaneously) without component conflicts -- though
  you must manage consistency yourself.

- **Data Storage:** Each state's data lives entirely on the state entity
  as components. This means you don't pollute the owner with components
  that are only relevant in one state. For instance, if the
  \"Attacking\" state needs a `AttackCooldown` component, that component
  exists on the AttackState entity, not on the owner. The state entity
  can also hold common FSM data like a `FsmState` component (to store
  state name or start time) and the back-reference to the
  owner[\[24\]](https://discussions.unity.com/t/any-burst-enabled-dots-state-machines-out-there/948011#:~:text=Engine%20discussions,component%20that%20the%20owner).
  Because the state entity is an ECS citizen, you can even have *systems
  per state* processing those state entities (similar to
  component-per-state pattern but now these systems run on state
  entities). The owner entity remains relatively static, probably only
  with general components like Transform, Health, etc., and one pointer
  to its state.

**Use Cases:** The state-as-entity pattern is often used in scenarios
where state logic is complex or heavy enough to warrant its own entity
context. It's seen in some **Unity DOTS** experiments and discussions
for AI and gameplay FSMs. For example, if an NPC has a very complex AI
state machine, making each state a self-contained entity can improve
organization: you could even dynamically compose states by adding
components to the state entity. It's also useful when an entity might
need **multiple state machines simultaneously**. Unity's ECS manual
notes that having more than one FSM on a single entity can cause
combinatorial explosion of state components and archetypes; the advice
is to *split entities to simplify* in such
cases[\[25\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=You%20might%20encounter%20more%20issues,entities%20to%20simplify%20these%20cases).
The state-entity pattern is one way to implement that split: e.g. an
entity's movement state vs. emotional state could be two separate child
entities, so they don't interfere. For **animation**, one might imagine
each animated entity owning an \"AnimationState\" entity that goes
through an animation FSM (with states like IdleAnim, RunAnim, JumpAnim
as entities). For **UI**, this pattern is less common, but one could
envision a UI workflow where each UI screen or dialog is an entity and a
master UI FSM entity spawns the appropriate screen entity according to
state. Generally, this pattern shines when you want to keep the owner
entity's data minimal and avoid frequent structural modifications on it.

**Advantages:** The main advantage is **decoupling state changes from
the owner's archetype**. The owner entity can remain in a stable chunk,
which is good for performance if the owner has heavy data (like physics
or rendering components that you don't want to shuffle around). All the
churn happens on lightweight state entities. It also encourages a clear
separation of concerns: state-specific data and logic live on the state
entity. You can even reuse state entity definitions between different
owners -- a form of composability (e.g. many enemies might spawn the
same `AlertState` entity type when alerted, reusing the same logic).
Systems operating on state entities naturally only see entities that are
in that state, so you get the benefit of data-oriented grouping without
changing the owner\'s structure. Debugging can be done by inspecting the
linked state entity to see what state an NPC is in and what data that
state holds. Another perk is that this pattern can simplify **temporary
or timed states**. For example, if a power-up effect is a state, you
spawn a \"PowerUpState\" entity with a lifetime; when it expires (entity
destroyed), you know the state ended.

**Trade-offs:** This approach is more complex to implement and
understand. It introduces an extra level of indirection (two entities
for one conceptual actor), which can complicate debugging if tools are
not designed for it. There is a runtime cost to creating and destroying
entities on transitions, though if transitions are not extremely
frequent this is usually negligible (ECS can handle lots of short-lived
entities, especially if pooled). Also, accessing the owner's data from a
state entity system means jumping references -- potentially a cache miss
to go fetch the owner's components. If, for example, the `ChaseSystem`
runs on `ChaseState` entities, and needs to read the owner's
`Transform`, it has to follow the owner reference and then read that
data, which might not be in the same chunk. This is a possible
performance downside compared to the pure tag approach (where the state
and the transform could be in the same chunk if they are on one entity).
In practice, this may be mitigated by careful arrangement or by copying
needed data into the state entity on creation. Another consideration is
tooling: not all engines have out-of-the-box support for visualizing
"entity relations". You might have to build custom debugging to see
"Entity 100 (NPC) is in state Entity 200 (Chasing)". Despite these
drawbacks, the state-as-entity pattern can be very **powerful for
complex FSMs** and is a valid option to keep your main data clean and
your state logic flexible.

## System-Based FSM (System Scheduling & Phases) {#system-based-fsm-system-scheduling-phases}

All the above patterns manage state at the **entity level**, but it\'s
also possible to implement FSM logic by controlling which **systems**
run, effectively making the *system execution* correspond to states.
This can be thought of as an **engine-level or global FSM**. Instead of
tagging entities or switching data, you *enable/disable entire systems
or groups of systems* to reflect the current state of the game or a
subset of the game.

- **Implementation:** Many ECS frameworks allow grouping systems or
  toggling their execution. For example, Unity DOTS has **System
  Groups** (like `PausedSystemGroup`, `GameplaySystemGroup`) which can
  be updated or skipped based on a game state
  variable[\[26\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=We%20can%20stop%20running%20the,be%20used%20for%20this%20purpose).
  In a system-based FSM, you define separate sets of systems for each
  high-level state. A classic use is game flow: you might have one set
  of systems active in the Main Menu state, and a different set in the
  Gameplay state. Toggling states means switching which system group is
  updating. This can be done via a master system or by the engine's
  scheduler when a state variable changes. Some ECS designs call these
  sets **phases** -- effectively engine states where only a certain
  subset of systems
  run[\[27\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=change%20its%20behavior%20by%20delegating,systems%20based%20on%20state).
  At a smaller scale, one could do this per entity as well (e.g.
  dedicate a unique system to a single entity's state), but that's
  usually not efficient for many entities.

- **State Transitions:** Occur by **re-scheduling systems**. For
  instance, a `StateManagerSystem` might detect a state change (perhaps
  from a singleton component or event) and respond by disabling the
  `MovementSystem`, `CombatSystem`, etc., and enabling a
  `MenuInputSystem` and `MenuRenderSystem`, if we transitioned from
  Playing to Menu. In Unity ECS, you might achieve this by moving
  systems into an inactive group or simply not calling `Update()` on
  certain system groups when in a given
  state[\[26\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=We%20can%20stop%20running%20the,be%20used%20for%20this%20purpose).
  Another example: to implement a **Pause** state, instead of tagging
  entities as paused, you could just not run any of the gameplay update
  systems while
  paused[\[26\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=We%20can%20stop%20running%20the,be%20used%20for%20this%20purpose).
  Transitioning back resumes those systems. At an extreme, one can even
  create/destroy systems on the fly (though typically systems are just
  dormant). Ash framework's engine-level FSM worked by **swapping out
  sets of systems** to change game
  modes[\[28\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=transition%20from%20one%20state%20to,another)[\[29\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=Alternatively%2C%20taking%20the%20Engine%20FSM,in%20some%20cases%20as%20well).
  One must be careful that when a system is disabled, any stateful
  processes it was doing are either also paused or cleaned up
  appropriately.

- **Data Storage:** States in this approach are often represented by a
  **singleton component or global variable** that systems read to decide
  if they should run. For example, a singleton `GameState` component (or
  just a static enum) could hold values like Menu/Playing/Paused.
  Systems might check this, or better, the scheduler handles it (more
  declaratively). The state data might also reside in separate ECS
  worlds entirely (Unity's older ECS suggestion was to use separate
  worlds for different scenes or game
  modes[\[30\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=When%20we%20want%20to%20manage,but%20on%20a%20smaller%20scale)).
  In terms of entity data, the data doesn't necessarily change when
  systems switch -- it's just not being processed. However, you might
  still combine this with other patterns. For instance, you could set a
  tag on all entities that should be frozen when paused, and your
  PauseSystemGroup simply doesn't run any system that would update
  those, or you disable updates of physics systems altogether.

**Use Cases:** System-based FSM is ideal for **coarse-grained states
that affect broad swaths of the game uniformly**, such as *game mode,
level, or UI vs gameplay*. For example, in a typical game you have the
menu state and the gameplay state. Rather than clutter every system with
"if (inMenu) return;", you can just not run the gameplay systems during
the menu. This results in a clean separation of code: menu-related
systems in one group, gameplay in another. Unity DOTS makes heavy use of
system groups to organize different phases of simulation
(Initialization, Simulation, Presentation), and one can extend that
concept to game-specific
states[\[31\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=Let%E2%80%99s%20see%20another%20example,%E2%80%9Cwhen%20a%20system%20should%20run%E2%80%9D).
It\'s also useful for things like **debug modes or feature toggles** --
enabling a suite of cheat systems only in a debug state, for instance.
In the context of a **single entity** with complex logic (say a boss
with multiple phases), one might implement each phase's behavior as a
separate system that runs only when the boss is in that phase. This is
unusual for large numbers of entities (you wouldn't make a new system
for every NPC's state), but for one-off cases it's viable.

**Advantages:** This approach excels in **maintainability and clarity**
at the high level. All logic for a given mode is self-contained in its
systems, and you avoid peppering entity-level code with checks for
whether it should run. A proponent of this approach noted that deciding
*when* a system runs can be handled outside the system, keeping the
system's responsibility focused (Single Responsibility
Principle)[\[32\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=easily%20put%20the%20application%20in,as%20we%20have%20more%20states)[\[33\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=In%20this%20case%2C%20the%20MovementSystem,the%20execution%20of%20other%20systems).
It also naturally prevents work from happening when it shouldn't (no
need to iterate over entities just to early-out because the game is
paused; those systems simply don't execute). Performance can therefore
be optimal by skipping whole systems rather than branching inside them.
For global states like **Paused**, this is arguably the simplest and
cleanest solution: pause = stop advancing simulation systems. System
gating is also the only real way to handle ECS vs non-ECS boundaries
like switching scenes or radically different game flows (you might even
unload entire worlds).

**Trade-offs:** The granularity of this method is limited. It doesn't
handle per-entity independent states well when those states differ among
many entities simultaneously -- that's what the earlier patterns are
for. If you tried to use system gating for many entities, you'd end up
with an explosion of systems (one per possible state per entity type),
which is not practical. So this pattern is complementary to entity-level
FSMs, not a replacement. Another issue is **tooling and dynamic
changes**: not all ECS frameworks allow enabling/disabling systems at
runtime easily (some require compile-time setup of system order).
However, many do support it either via grouping or filtering by a global
component. Also, if a system is off, any time-based processes in it need
to be accounted for (e.g. if AI thinking system is off for 5 seconds,
when it turns on, does it catch up or simply resume?). These are design
considerations but not unsolvable. In general, use system-level FSMs for
**broad context states** (game scenes, global modes) or very unique
situations, and use entity-level FSMs for individual entity behaviors.

Having described the major patterns, let\'s **compare them side by
side** on key criteria:

## Comparison of FSM Patterns in ECS

| **Approach**                                                                | **How It Works**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | **Pros**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | **Cons**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | **Best Use Cases**                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|-----------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Component-per-State** \<br\>(State as Tag Components)                     | Each state = unique component; add/remove to switch state. Systems filter by these components[\[3\]](https://github.com/skypjack/entt/discussions/1230#:~:text=It%20doesn%27t%20depend%20on%20EnTT,%E2%80%8D%E2%99%82%EF%B8%8F).                                                                                                                                                                                                                                                                                               | • Strong modularity -- separate systems for each state[\[3\]](https://github.com/skypjack/entt/discussions/1230#:~:text=It%20doesn%27t%20depend%20on%20EnTT,%E2%80%8D%E2%99%82%EF%B8%8F).\<br\>• Data-oriented grouping: entities in same state are co-located for iteration[\[4\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Group%20entity%20data%20according%20to,state%20data%20clustering).\<br\>• Easy to inspect an entity's state (just see its components).                                                                                                                                                                                                 | • State changes are structural (can be costly if frequent)[\[10\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,to%20query%20update%20and%20execution).\<br\>• Many states can cause many archetypes (fragmentation/cache misses)[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk).\<br\>• Must ensure exclusive tags (no invalid state combinations). | • AI with distinct behavior states (patrol, chase, attack).\<br\>• Player character modes (idle, running, jumping) for clean logic separation.\<br\>• Animation states where each requires different update logic.                                                                                                                                                                                                                                                                      |
| **Single FSM Component** \<br\>(State as Data/Enum)                         | One component holds current state (enum) and possibly shared data. A generic system branches on this state[\[13\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Keep%20entities%20with%20different%20states,states%20in%20a%20single%20job).                                                                                                                                                                                                                                     | • No structural changes on transition -- very fast updates[\[15\]](https://www.reddit.com/r/gamedev/comments/i7pkj3/why_storing_state_machines_in_ecs_is_a_bad_idea/#:~:text=Good%20question%21%20The%20states%20are,rewiring%20of%20the%20linked%20lists).\<br\>• Single archetype -- avoids state explosion, good for many states.[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk)\<br\>• Simpler when FSM is small; one place to manage logic.                                                                                                                                                                             | • Logic not modular -- tends toward large switch statements (harder to extend).\<br\>• Less data-oriented -- branches per entity, possible wasted processing on irrelevant states[\[16\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=For%20more%20information%2C%20refer%20to,This%20also%20increases%20cache%20misses).\<br\>• State-specific data may be awkwardly packed into one component.                                              | • Simple or global state machines (game mode, UI mode) with few entities but frequent toggles.\<br\>• Player state if keeping all logic in one system for simplicity.\<br\>• Prototyping an FSM quickly without setting up many components/systems.                                                                                                                                                                                                                                     |
| **FSM Component + Tags** \<br\>(Component-based FSM with Transition System) | Combination of state tags and an FSM manager component that orchestrates transitions[\[23\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=In%20more%20naive%20approaches%20to,a%20member%20of%20a%20system)[\[18\]](https://github.com/Seldom-SE/seldom_state#:~:text=%60seldom_state%60%20is%20a%20component,components%20directly%20in%20your%20systems). The FSM component knows which components to add/remove for each state.                   | • Eliminates ad-hoc if/else in systems -- transitions are data-driven[\[23\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=In%20more%20naive%20approaches%20to,a%20member%20of%20a%20system).\<br\>• Still modular at runtime (state-specific systems) but with centralized control of switching.\<br\>• Easier to maintain complex graphs of states (clear definition of transitions in one place).                                                                                                                                                                                                                                        | • Adds complexity: need to define and maintain the FSM data structure.\<br\>• Transition overhead similar to component-per-state (still does add/remove under the hood).\<br\>• Slight indirection can complicate debugging of timing (transition happens via manager).                                                                                                                                                                                                                      | • Complex NPC AI or game logic where transitions logic is non-trivial (e.g. combo attack chains, boss phases) and benefits from a clear state graph.\<br\>• Reusing FSM designs across multiple entities (configure once, apply to many).\<br\>• When tool support exists (visual editors for state graphs) to configure FSMs in ECS.                                                                                                                                                   |
| **State-as-Entity** \<br\>(State Entity Pattern)                            | The entity's state is externalized as another entity with its own components; owner links to state entity[\[24\]](https://discussions.unity.com/t/any-burst-enabled-dots-state-machines-out-there/948011#:~:text=Engine%20discussions,component%20that%20the%20owner). Transition = swap state entities.                                                                                                                                                                                                                       | • Owner's components remain static -- no churning heavy data[\[25\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=You%20might%20encounter%20more%20issues,entities%20to%20simplify%20these%20cases).\<br\>• State data completely isolated to state entity (no pollution of owner with unused comps).\<br\>• Allows multiple concurrent state machines by using multiple state entities per owner (solves exclusive tag problem)[\[25\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=You%20might%20encounter%20more%20issues,entities%20to%20simplify%20these%20cases).                                                  | • More complex architecture -- two kinds of entities to manage per actor.\<br\>• Transition still structural (create/destroy state entity), plus pointer chasing to access owner's data (cache cost).\<br\>• Tooling/mental overhead to track state relationships.                                                                                                                                                                                                                           | • Agents with very **rich state data** or many optional state-specific components (so that attaching/detaching them on one entity would be too much overhead or complexity).\<br\>• Situations with **overlapping states** or multiple FSMs on one entity -- splitting into separate state entities avoids component conflicts.\<br\>• Cases where you want to reuse state logic by swapping in a "state entity template" (e.g. plug in a different state behavior module dynamically). |
| **System-Gating FSM** \<br\>(Engine/Global State)                           | Different sets of systems correspond to different overall states; enable/disable system groups to switch mode[\[26\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=We%20can%20stop%20running%20the,be%20used%20for%20this%20purpose)[\[29\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=Alternatively%2C%20taking%20the%20Engine%20FSM,in%20some%20cases%20as%20well). | • Very clear separation of code by state -- no unnecessary system runs when not needed[\[32\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=easily%20put%20the%20application%20in,as%20we%20have%20more%20states).\<br\>• No per-entity overhead; great for global modes like menus, pause (skip processing entirely).\<br\>• Preserves Single Responsibility in systems (each system always does one thing in the right context)[\[32\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=easily%20put%20the%20application%20in,as%20we%20have%20more%20states). | • Not suitable for per-entity independent states at scale (doesn't handle many entities each in different states).\<br\>• Requires the ECS framework to support dynamic system scheduling or conditional execution (not all do easily).\<br\>• Can complicate time management (if systems paused, time steps might need freezing, etc.).                                                                                                                                                     | • **Game state management**: menu, gameplay, paused, cut-scene mode, where each mode runs distinct logic.\<br\>• **Level transitions or screens**: completely different logic sets per stage of game.\<br\>• Single-entity special cases (e.g. one hero with distinct phases implemented by separate systems -- though usually other patterns suffice).                                                                                                                                 |

**Performance:** In terms of raw performance, the component-per-state
and state-as-entity patterns shine when many entities share the same
state because they leverage data locality and avoid per-entity
branching. They do incur structural change costs on transitions, but if
transitions are relatively infrequent (or batched outside of critical
loops), they benefit from tight, linear iteration in the steady state.
The single-component (state enum) approach avoids structural changes
altogether, which is great for very frequent state flips, but at the
cost of more branching and potentially touching more data than
necessary. Unity's analysis suggests that if a lot of entities sit in an
"idle" state, single-branch systems might waste time skipping
them[\[16\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=For%20more%20information%2C%20refer%20to,This%20also%20increases%20cache%20misses),
whereas a tag-based approach would simply not include them in the active
query. Enableable components can offer a middle ground by making those
idle entities get skipped at chunk
granularity[\[12\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,iterate%20over%20entities%20and%20check)
(so the overhead of checking them is minimal). The state-as-entity
introduces an extra indirection which could have cache impacts, but it
keeps the main entity hot in cache if its components never change
archetype. System gating, when applicable, is very efficient globally
(skip entire systems), but doesn't help within a single system's inner
loop since it's an orthogonal level of control.

**Modularity and Readability:** Component-per-state and
FSM-with-components both score high on modularity -- you can add a new
state by adding a new component and system, without touching existing
ones. The code for each state is isolated, improving readability (no
giant switch-case). On the other hand, the single-component approach
centralizes logic; while this can be easier to initially grasp in one
file, it tends to grow and can violate modular design as more states are
jammed into one system. The state-as-entity pattern is modular in terms
of data (each state entity can be seen as a module), but you might still
implement logic either in one system branching on state type or multiple
systems targeting different state entity tags. It can be very elegant
for modular design if you treat state entities as pluggable modules.
System gating is very modular at the level of whole game modes, but not
applicable inside one mode. In terms of **ease of understanding**,
component-per-state is usually intuitive: "entity has component X, so
it's in state X". The state machine component approach might require
understanding the FSM configuration structure, which is an extra concept
but often mirrors well-known state chart representations.
State-as-entity is arguably the most conceptually complex, because one
entity spawning another to represent a state is not an immediately
obvious pattern to newcomers.

**Tooling and Debugging:** This often depends on engine support. If your
ECS tools show you entity-component listings, then the
component-per-state pattern is great: you can literally see the state
component on the entity. If there's an issue, you might catch an entity
that erroneously has two state tags at once. Some frameworks might let
you enforce mutual exclusivity via code or archetype definitions. The
single-component FSM might be harder to debug at a glance -- you have to
inspect the data field to know the state. However, it has the advantage
that breakpoints in one system catch all state transitions and updates
in one place. With many systems (component-per-state), debugging a flow
might involve hopping between different systems as the entity changes
state. The FSM manager pattern can improve clarity by providing logs or
callbacks on transitions (a good place to set breakpoints or print state
changes). State-as-entity can be tricky if your debugger doesn't
automatically associate the state entity with its owner; you may need
custom inspectors or to print out state entity info whenever you inspect
an owner. On the plus side, since state entities can be given
descriptive names or component tags, you might list all "ChaseState"
entities to see how many agents are chasing, etc., which is a form of
debugging insight. System gating is usually easy to debug at a high
level (you know what mode you're in and thus which systems are running),
but you need to ensure no disabled system inadvertently leaves something
in a bad state when turned off. Logging entering/exiting of modes is
straightforward and can aid debugging.

**Choosing an Approach -- Use Case Suitability:** In practice, these
patterns can be mixed and matched. For **AI behaviors** in a game with
many NPCs, a **component-per-state** or **FSM component+tags** approach
is often ideal. It scales to many entities and keeps their logic cleanly
separated. If the AI is simple (few states) and performance isn't
critical, a single FSM component with an enum might suffice too (simpler
to implement, but less optimal for large numbers). For a **player
character**, which is a unique entity, you have more freedom: using a
traditional OOP-like FSM inside a component (even holding pointers to
state classes as Skypjack suggested is
possible[\[34\]](https://github.com/skypjack/entt/discussions/1230#:~:text=Otherwise%2C%20you%20can%20have%20a,%E2%80%8D%E2%99%82%EF%B8%8F))
might be okay since there's just one player. But if you want to stay
pure ECS, you could still use state tags or an FSM component. Unity's
ECS samples have demonstrated player state with enableable components to
quickly disable input/movement when needed, for example. For **animation
systems**, often performance is paramount because potentially every
animated entity ticks every frame. A data-oriented approach is used:
e.g. grouping entities by animation state for SIMD evaluation. Tag
components or shared component values (e.g. current animation ID) can be
used so that the animation system processes one state at a time in bulk.
If using a high-level FSM to control animation sequences, a StateMachine
component (like an animation graph) could drive which animation
components are present. **UI flows** (menus, screens) are usually best
handled by the **system-gating or singleton FSM** approach. There are
typically very few UI states but they affect large parts of the game, so
toggling systems or whole sets of entities on/off is logical. For
instance, you might simply have separate ECS worlds for UI vs game in
some engines, or a single world with a `UIState` that systems check to
render or not render UI entities.

In conclusion, implementing FSMs in ECS requires balancing **data
layout** with **code clarity**. No single pattern is universally "best"
-- each has
trade-offs[\[34\]](https://github.com/skypjack/entt/discussions/1230#:~:text=Otherwise%2C%20you%20can%20have%20a,%E2%80%8D%E2%99%82%EF%B8%8F).
For small-scale or global states, a simple data field or system toggle
might be easiest. For entity-specific behaviors especially at scale,
leveraging ECS strengths with state components or even state entities
leads to more scalable and maintainable designs. Many robust ECS-based
games use a mix: for example, a global game mode FSM (system gating)
combined with per-entity AI state tags for NPC behaviors, and perhaps an
FSM component for complex boss logic. By understanding these patterns
and their implications, you can apply the right strategy for each
context, achieving both clean architecture and high performance in an
ECS-based project.

**Sources:**

- Unity DOTS Manual -- *Implementing state machines* (Unity ECS
  approaches: per-state components, branching,
  etc.)[\[4\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Group%20entity%20data%20according%20to,state%20data%20clustering)[\[35\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Per)[\[36\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,refer%20to%20Managing%20chunk%20allocations)[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk)[\[25\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=You%20might%20encounter%20more%20issues,entities%20to%20simplify%20these%20cases)
- skypjack (EnTT) -- FSM in ECS Q&A (suggests state-as-component vs
  state-in-component vs hybrid
  OOP)[\[3\]](https://github.com/skypjack/entt/discussions/1230#:~:text=It%20doesn%27t%20depend%20on%20EnTT,%E2%80%8D%E2%99%82%EF%B8%8F)[\[14\]](https://github.com/skypjack/entt/discussions/1230#:~:text=One%20way%20to%20do%20that,%E2%80%8D%E2%99%82%EF%B8%8F)
- Sander Mertens -- *Why Storing State Machines in ECS is a bad idea*
  (discussion of efficient FSM storage; switchable
  components)[\[15\]](https://www.reddit.com/r/gamedev/comments/i7pkj3/why_storing_state_machines_in_ecs_is_a_bad_idea/#:~:text=Good%20question%21%20The%20states%20are,rewiring%20of%20the%20linked%20lists)
- Richard Lord -- *Ash Framework: Finite State Machines* (component
  composition mapped to states, engine/system-level
  FSM)[\[23\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=In%20more%20naive%20approaches%20to,a%20member%20of%20a%20system)[\[22\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=fsm.CreateState%28)
- Bevy `seldom_state` -- ECS state machine plugin (component-based
  states with triggers and
  transitions)[\[18\]](https://github.com/Seldom-SE/seldom_state#:~:text=%60seldom_state%60%20is%20a%20component,components%20directly%20in%20your%20systems)[\[20\]](https://github.com/Seldom-SE/seldom_state#:~:text=A%20state%20is%20a%20component,state%20according%20to%20those%20transitions)
- Behnam Rasooli -- *Managing States in ECS* (Unity ECS example for
  paused vs running via system groups vs component
  tags)[\[26\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=We%20can%20stop%20running%20the,be%20used%20for%20this%20purpose)[\[37\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=Problem%20with%20the%20component)[\[30\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=When%20we%20want%20to%20manage,but%20on%20a%20smaller%20scale).

[\[1\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=However%2C%20everything%20changes%20when%20you,they%20only%20care%20about%20the)
[\[2\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=The%20best%20way%20,conditions%20to%20transition%20between%20states)
[\[5\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=To%20make%20managing%20the%20state,to%20be%20in%20various%20states)
[\[6\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=)
[\[7\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=States%20are%20no%20longer%20objects,held%20by%20the)
[\[8\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=,held%20by%20the%20entity)
[\[22\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=fsm.CreateState%28)
[\[23\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=In%20more%20naive%20approaches%20to,a%20member%20of%20a%20system)
[\[27\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=change%20its%20behavior%20by%20delegating,systems%20based%20on%20state)
[\[28\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=transition%20from%20one%20state%20to,another)
[\[29\]](https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system#:~:text=Alternatively%2C%20taking%20the%20Engine%20FSM,in%20some%20cases%20as%20well)
oop - Finite State Machine Implementation in an Entity Component
System - Stack Overflow

<https://stackoverflow.com/questions/39185133/finite-state-machine-implementation-in-an-entity-component-system>

[\[3\]](https://github.com/skypjack/entt/discussions/1230#:~:text=It%20doesn%27t%20depend%20on%20EnTT,%E2%80%8D%E2%99%82%EF%B8%8F)
[\[14\]](https://github.com/skypjack/entt/discussions/1230#:~:text=One%20way%20to%20do%20that,%E2%80%8D%E2%99%82%EF%B8%8F)
[\[34\]](https://github.com/skypjack/entt/discussions/1230#:~:text=Otherwise%2C%20you%20can%20have%20a,%E2%80%8D%E2%99%82%EF%B8%8F)
ECS and finite state machine · skypjack entt · Discussion \#1230 ·
GitHub

<https://github.com/skypjack/entt/discussions/1230>

[\[4\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Group%20entity%20data%20according%20to,state%20data%20clustering)
[\[10\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,to%20query%20update%20and%20execution)
[\[11\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,together%20in%20the%20same%20chunk)
[\[12\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,iterate%20over%20entities%20and%20check)
[\[13\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Keep%20entities%20with%20different%20states,states%20in%20a%20single%20job)
[\[16\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=For%20more%20information%2C%20refer%20to,This%20also%20increases%20cache%20misses)
[\[17\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=having%20all%20entities%20in%20the,This%20also%20increases%20cache%20misses)
[\[25\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=You%20might%20encounter%20more%20issues,entities%20to%20simplify%20these%20cases)
[\[35\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=Per)
[\[36\]](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html#:~:text=,refer%20to%20Managing%20chunk%20allocations)
Implement state machines \| Entities \| 1.3.10

<https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/state-machine.html>

[\[9\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=Problem%20with%20the%20component)
[\[26\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=We%20can%20stop%20running%20the,be%20used%20for%20this%20purpose)
[\[30\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=When%20we%20want%20to%20manage,but%20on%20a%20smaller%20scale)
[\[31\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=Let%E2%80%99s%20see%20another%20example,%E2%80%9Cwhen%20a%20system%20should%20run%E2%80%9D)
[\[32\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=easily%20put%20the%20application%20in,as%20we%20have%20more%20states)
[\[33\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=In%20this%20case%2C%20the%20MovementSystem,the%20execution%20of%20other%20systems)
[\[37\]](https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46#:~:text=Problem%20with%20the%20component)
Managing States in Entity-Component-System (aka Finite-State-Machine) -
part 1 \| by Behnam Rasooli \| Medium

<https://medium.com/@ben.rasooli/managing-states-in-entity-component-system-aka-finite-state-machine-8db8d19dec46>

[\[15\]](https://www.reddit.com/r/gamedev/comments/i7pkj3/why_storing_state_machines_in_ecs_is_a_bad_idea/#:~:text=Good%20question%21%20The%20states%20are,rewiring%20of%20the%20linked%20lists)
Why Storing State Machines in ECS is a bad idea. : r/gamedev

<https://www.reddit.com/r/gamedev/comments/i7pkj3/why_storing_state_machines_in_ecs_is_a_bad_idea/>

[\[18\]](https://github.com/Seldom-SE/seldom_state#:~:text=%60seldom_state%60%20is%20a%20component,components%20directly%20in%20your%20systems)
[\[19\]](https://github.com/Seldom-SE/seldom_state#:~:text=and%20one%20to%20transition%20to%3B,state%20according%20to%20those%20transitions)
[\[20\]](https://github.com/Seldom-SE/seldom_state#:~:text=A%20state%20is%20a%20component,state%20according%20to%20those%20transitions)
[\[21\]](https://github.com/Seldom-SE/seldom_state#:~:text=MyInitialState%3A%3Anew%28%29%2C%20StateMachine%3A%3Adefault%28%29%20.trans%3A%3A,MyBundle)
GitHub - Seldom-SE/seldom_state: Component-based state machine plugin
for Bevy. Useful for AI, player state, and other entities that occupy
different states.

<https://github.com/Seldom-SE/seldom_state>

[\[24\]](https://discussions.unity.com/t/any-burst-enabled-dots-state-machines-out-there/948011#:~:text=Engine%20discussions,component%20that%20the%20owner)
Any Burst-enabled DOTS State Machines out there? - Unity Engine

<https://discussions.unity.com/t/any-burst-enabled-dots-state-machines-out-there/948011>
