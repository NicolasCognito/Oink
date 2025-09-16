# Tiny‑BT Tasks: A Practical Guide

This guide documents the task‑oriented behavior tree variant for tiny‑ecs. It explains how to define trees, register conditions and tasks, integrate systems, and debug running behavior. It assumes you’re using `tiny-bt-tasks.lua` with the extended decorator set.

---

## 1) Core idea

* **Owner entity:** the game agent that owns the BT instance.
* **Task entity:** a short‑lived ECS entity created by a `task` leaf to perform work. The BT returns `RUNNING` until the task entity marks completion.
* **Completion contract:** every task entity must eventually set:

  * `task_complete = true`
  * `task_result = bt.SUCCESS | bt.FAILURE`
  * Optional: set `task_cancelled = true` if the BT aborted the branch.

The BT engine polls the task entity each tick. When `task_complete` is seen, it consumes `task_result`, removes the task entity from the world, and resumes the tree.

---

## 2) Quick start

```lua
local bt = require('tiny-bt-tasks')
local T  = bt.dsl

-- 1) Register a condition
bt.register_condition('enemy_visible', function(owner, params)
  return owner.senses and owner.senses.enemy ~= nil
end)

-- 2) Register a task
bt.register_task('move_to', {
  validate = function(owner, p) return owner.position and p and p.x and p.y end,
  spawn = function(owner, world, p)
    local e = { bt_task=true, task_type='move', owner=owner, target={x=p.x,y=p.y}, speed=p.speed or 5 }
    world:addEntity(e)  -- processed by your MoveTaskSystem (see §6)
    return e
  end
})

-- 3) Build a tree
local tree = bt.build(T.selector({
  T.sequence({
    T.condition('enemy_visible'),
    T.cooldown(2.0, T.task('move_to', {x=10,y=6,speed=8}))
  }),
  T.wait(0.25, T.succeeder(T.task('move_to', {x=0,y=0})))
}))

-- 4) Attach an instance to an entity and run the system
agent.bt = bt.instance(tree, { tick_interval = 0.05, name = 'guard_01' })
world:addSystem(bt.system())
world:addSystem(bt.move_task_system())  -- example from §6
```

---

## 3) DSL reference

**Composites**

* `sequence{ child1, child2, ... }` → fails fast on first failure, succeeds when all succeed.
* `selector{ child1, child2, ... }` → succeeds fast on first success, fails when all fail.
* `parallel(children, opts)` → runs children concurrently.

  * `opts.success` = successes needed to succeed (default all)
  * `opts.failure` = failures needed to fail (default 1)

**Leaves**

* `condition(name, params)` → calls registered function `fn(owner, params) -> boolean`.
* `task(name, params)` → spawns a task entity using registered task def.

**Decorators**

* `inverter(child)`
* `succeeder(child)`
* `failer(child)`
* `repeat_n(child, count)`
* `until_success(child)`
* `until_failure(child)`
* `wait(seconds, child)`
* `cooldown(seconds, child)`
* `time_limit(seconds, child)`

Time‑based decorators require the BT system to receive `dt` each tick. The provided system forwards `dt` for you.

---

## 4) Registering leaves

### Conditions

```lua
bt.register_condition('has_ammo', function(owner)
  return (owner.ammo or 0) > 0
end)
```

* Keep pure and fast.
* Use `params` for constants, not for dynamic state. Read dynamic state from `owner`.

### Tasks

```lua
bt.register_task('shoot', {
  validate = function(owner, p)
    return (owner.ammo or 0) > 0 and owner.weapon
  end,
  spawn = function(owner, world, p)
    local e = { bt_task=true, task_type='shoot', owner=owner, rounds=p.rounds or 1 }
    world:addEntity(e)  -- processed by your ShootTaskSystem
    return e
  end
})
```

**Contract:** your system must later set `e.task_complete=true` and `e.task_result=bt.SUCCESS|bt.FAILURE`. If the BT cancels the branch, it will set `e.task_cancelled=true` before removing state.

---

## 5) Execution model and lifecycle

* One BT instance per owner: `owner.bt = bt.instance(tree, {tick_interval=0.05, name='npc'})`.
* Engine system: `world:addSystem(bt.system({ interval=nil }))`.

  * `interval` throttles system updates globally. Prefer per‑entity `tick_interval` for fine control.
* Each tick the engine calls into the root node. For a `task` leaf it will:

  1. Run `validate` if present. If false → `FAILURE`.
  2. Call `spawn(owner, world, params)`.
  3. Store the returned task entity and return `RUNNING`.
  4. On later ticks, poll `task_complete` and consume `task_result`.
* Reset and cancellation

  * When a branch completes or is abandoned, the engine resets its subtree and sets `task_cancelled=true` on any live task entities in that subtree.
  * `bt.cancel(owner)` resets the whole tree now.

---

## 6) Writing task systems

A system consumes task entities. Example: move‑to target.

```lua
local tiny = require('tiny')

function bt.move_task_system()
  local sys = tiny.processingSystem()
  sys.filter = tiny.requireAll('task_type', 'target')
  sys.name = 'MoveTaskSystem'

  function sys:process(e, dt)
    if e.task_type ~= 'move' then return end
    if e.task_cancelled then e.task_complete=true; e.task_result=bt.FAILURE; return end

    local owner = e.owner; if not owner or not owner.position then e.task_complete=true; e.task_result=bt.FAILURE; return end

    local dx, dy = e.target.x - owner.position.x, e.target.y - owner.position.y
    local d = math.sqrt(dx*dx + dy*dy)
    if d < 0.5 then e.task_complete=true; e.task_result=bt.SUCCESS; return end

    local speed = e.speed or 5
    local step = speed * dt
    owner.position.x = owner.position.x + (dx/d) * step
    owner.position.y = owner.position.y + (dy/d) * step
  end

  return sys
end
```

Guidelines

* Keep task entities minimal. Only fields the system needs.
* Make systems idempotent per tick. Return early when complete.
* Respect `task_cancelled` and finish cleanly.

---

## 7) Decorator semantics

* **inverter**: SUCCESS ↔ FAILURE. RUNNING passes through.
* **succeeder**: Always returns SUCCESS once child resolves. RUNNING passes through.
* **failer**: Always returns FAILURE once child resolves. RUNNING passes through.
* **repeat\_n**: Re‑runs child each time it resolves. Succeeds after `count` completions. Infinite when `count=nil`.
* **until\_success / until\_failure**: Keep re‑running child until it returns the target status, then `SUCCESS`.
* **wait(s, child)**: Do nothing for `s` seconds, then run child once.
* **cooldown(s, child)**: After a SUCCESS, immediately return FAILURE for `s` seconds before the next attempt.
* **time\_limit(s, child)**: If child hasn’t resolved within `s` seconds, fail and reset the child.

Tips

* Combine `cooldown` with `selector` to back off noisy tasks.
* Wrap risky tasks with `time_limit` to prevent stalls if a system breaks.

---

## 8) Parallel patterns

`parallel(children, {success=K, failure=M})`

* Starts all children. Tracks each child’s terminal status.
* When `success` threshold is met, cancels unfinished children and returns SUCCESS.
* When `failure` threshold is met, cancels unfinished children and returns FAILURE.
* Default: `success=#children`, `failure=1`.

Use cases

* Race strategies: e.g., `parallel({ pathfind, time_limit(0.5, fallback) }, {success=1})`.
* Supervisors: one child monitors health while others act.

---

## 9) Debugging and observability

* **Inspect task entities** in your ECS inspector or log:

  * `bt_task`, `task_type`, `owner`, `task_cancelled`, `task_complete`, `task_result`.
* **Tree state** lives in `owner.bt.node_states[node_id]`. You can dump or watch these.
* **Trace logs**: print in your systems when setting `task_complete`, including the owning BT name if you set one in `bt.instance(... {name='...'})`.
* **Cancel stuck work**: call `bt.cancel(owner)` to reset the whole tree.

Optional helper for “is anything running?”

```lua
local function bt_any_task_running(owner)
  local st = owner.bt; if not st then return false end
  for id, s in pairs(st.node_states) do
    if s.task_entity and not s.task_entity.task_complete then return true end
  end
  return false
end
```

---

## 10) Performance guidelines

* Prefer `tick_interval` per owner over a global system `interval`.
* Guard `task` leaves with cheap `condition` checks to avoid spawning every tick.
* Use `cooldown` to cap retry frequency of expensive tasks.
* Avoid large task graphs if systems can batch work.

---

## 11) Porting between Action‑ and Task‑based trees

Action → Task

* Wrap the action body into a task system. Map `validate` to task `validate`. Map the action’s lifecycle to system updates until completion.
* Replace `action{name='X'}` with `task('X')` in the tree.

Task → Action

* Create an action whose `start` spawns the task entity and whose `tick` polls `task_complete`.
* On `abort`, set `task_cancelled=true` on the entity.

Structure, composites, and decorators port 1:1.

---

## 12) Common pitfalls

* **Task never finishes**: system forgot to set `task_complete` or keeps recreating the entity. Fix by setting terminal flags once and returning.
* **Timers don’t work**: engine must receive `dt`. Use the provided `bt.system` and ensure your world passes `dt` into `:process`.
* **Cancel doesn’t propagate**: ensure your systems check `task_cancelled` and exit with a terminal result.
* **Over‑spawning**: put `condition` and `cooldown` ahead of `task` leaves.

---

## 13) Testing template

```lua
-- Minimal test loop
local world = tiny.world(bt.system(), bt.move_task_system())
local agent = { position={x=0,y=0} }
world:addEntity(agent)

agent.bt = bt.instance(bt.build(T.sequence({
  T.task('move_to', {x=5,y=0,speed=10})
})), {tick_interval=0.02, name='test'})

for i=1,300 do world:update(1/60) end
-- Expect agent.position.x ~= 0 and the task to complete
```

---

## 14) API summary

```lua
-- Registration
bt.register_condition(name, fn(owner, params) -> boolean)
bt.register_task(name, { validate?(owner, params) -> bool, spawn(owner, world, params) -> task_entity })

-- Build + instance
bt.build(dsl_tree) -> {root, nodes}
bt.instance(tree, {tick_interval?, name?, debug?}) -> state_table

-- DSL (bt.dsl)
sequence{...}, selector{...}, parallel(children, {success?, failure?})
condition(name, params?)
task(name, params?)
-- decorators
inverter, succeeder, failer, repeat_n, until_success, until_failure,
wait(seconds, child), cooldown(seconds, child), time_limit(seconds, child)

-- Systems
bt.system({filter?, interval?}) -> tiny system
-- example systems
bt.move_task_system() -- demo implementation

-- Control
bt.cancel(owner) -- reset and cancel outstanding tasks
```

That’s it. Build small, composable tasks, wire clear completion, and let the tree coordinate them.
