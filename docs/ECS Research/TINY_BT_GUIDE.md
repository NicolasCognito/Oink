# Tiny‑BT for tiny‑ecs — Developer Guide

A behavior‑tree runtime and DSL built to run on top of \[tiny‑ecs]. You build one shared tree asset, attach light per‑entity state, and tick via a tiny processing system.

---

## 1. Install

1. Put `tiny-bt.lua` somewhere on your Lua package path.
2. Require it where you set up your world:

   ```lua
   local tiny = require('tiny')
   local bt   = require('tiny-bt')
   local T    = bt.dsl
   ```

---

## 2. Quick start

```lua
-- 1) Define leaves
bt.register_condition('HasTarget', function(ctx)
  return ctx.entity.target ~= nil
end)

bt.register_action('Chase', {
  start=function(ctx) ctx.state.timer = 0 end,
  tick=function(ctx, dt)
    ctx.state.timer = ctx.state.timer + dt
    -- move towards ctx.entity.target here
    return bt.RUNNING -- or bt.SUCCESS / bt.FAILURE
  end,
  abort=function(ctx) -- stop movement if needed end,
})

bt.register_action('Idle', { tick=function(ctx, dt) return bt.RUNNING end })

-- 2) Describe the tree with the DSL, then build a compact asset
local tree = bt.build(
  T.selector{
    T.sequence{
      T.condition{ name='HasTarget' },
      T.action{ name='Chase', params={ max_speed=120 } },
    },
    T.action{ name='Idle' },
  }
)

-- 3) Attach per‑entity runtime state
enemy.bt = bt.instance(tree, { tick_interval=0.05, stagger=true, name='EnemyAI' })

-- 4) Add the system once
world:addSystem(bt.system{})  -- default filter: entities with field `bt`
```

---

## 3. Concepts

* **Tree asset**: immutable structure shared by all entities.
* **Per‑entity instance**: small tables that store node status and tiny bits of memory.
* **Tick**: each update step drives the tree and returns node statuses.
* **Statuses**: `bt.SUCCESS`, `bt.FAILURE`, `bt.RUNNING`.
* **Blackboard**: light helper around the entity table.

---

## 4. ECS wiring

```lua
local sys = bt.system{
  -- filter = tiny.requireAll('bt'), -- default
  -- interval = 0.016,               -- optional global cadence
}
world:addSystem(sys)
```

Per‑entity cadence:

```lua
entity.bt = bt.instance(tree, { tick_interval = 0.1, stagger = true })
```

* `tick_interval`: time slice for this entity only. If nil, ticks every frame.
* `stagger`: randomizes first tick to avoid spikes. Set your own `math.randomseed(...)` for determinism.

---

## 5. The context object (`ctx`)

Provided to conditions and actions:

| Field    | Meaning                                        |
| -------- | ---------------------------------------------- |
| `world`  | tiny world                                     |
| `entity` | the current entity                             |
| `bb`     | blackboard helper; writes to entity fields     |
| `tree`   | current tree asset                             |
| `node`   | current node descriptor                        |
| `params` | per‑node params from the DSL                   |
| `state`  | small table you can use for this leaf instance |

Blackboard helpers:

```lua
ctx.bb:get('hp')         -- same as ctx.entity.hp
ctx.bb:set('hp', 50)
ctx.bb:has('target')
```

---

## 6. DSL reference

Composites:

```lua
T.sequence{ child1, child2, ... }     -- run in order; fail fast; succeed if all succeed
T.selector{ child1, child2, ... }     -- try in order; succeed on first success; otherwise fail
T.parallel({ child1, child2, ... }, { success=K, failure=J })
-- defaults: success = #children, failure = 1
```

Leaves:

```lua
T.condition{ name='Name', params={...} }
T.action{    name='Name', params={...} }
```

Decorators:

```lua
T.inverter(child)
T.succeeder(child)
T.failer(child)
T.repeat_n(child, n)
T.until_success(child)
T.until_failure(child)
T.wait(seconds, child)
T.cooldown(seconds, child)
T.time_limit(seconds, child)
```

Build:

```lua
local tree = bt.build(rootSpec)
```

---

## 7. Leaf APIs

### Conditions

```lua
bt.register_condition('HasAmmo', function(ctx)
  return (ctx.entity.ammo or 0) > 0
end)
```

* Return truthy to mean `SUCCESS`, falsy for `FAILURE`.
* No `RUNNING` state; conditions are instantaneous.

### Actions

```lua
bt.register_action('MoveTo', {
  validate=function(ctx) return ctx.params and ctx.params.target ~= nil end,
  start=function(ctx)
    ctx.state.elapsed = 0
    -- compute path or cache references
  end,
  tick=function(ctx, dt)
    ctx.state.elapsed = ctx.state.elapsed + dt
    -- step movement; return bt.RUNNING until arrival
    return bt.RUNNING
  end,
  abort=function(ctx)
    -- clean up if interrupted or if action fails
  end,
})
```

* `validate?` optional pre‑check. If returns `false`, action immediately returns `FAILURE` without calling `start`.
* `start?` called once on first entry.
* `tick` called each tick. Must return a status.
* `abort?` called when the action ends in `FAILURE` or is reset by the parent.
* Use `ctx.state` for per‑entity, per‑node ephemeral data.

---

## 8. Node semantics and resets

* **Sequence**: runs child `i` until it is `SUCCESS`. On `FAILURE`, sequence fails and the failed child subtree is reset. On final success, resets internal index to 1.
* **Selector**: tries child `i`. On `SUCCESS`, selector succeeds and resets all other children. On `FAILURE`, resets the failed child and tries the next.
* **Parallel**: ticks all unfinished children each tick. Tracks terminal children. Finishes `SUCCESS` when `success ≥ K`. Finishes `FAILURE` when `failure ≥ J`. Resets remaining unfinished children on finish.
* **Decorators**:

  * `inverter`: flip `SUCCESS`/`FAILURE`. `RUNNING` passes through.
  * `succeeder`: always `SUCCESS` after child stops running.
  * `failer`: always `FAILURE` after child stops running.
  * `repeat_n`: keep restarting child until it has run `n` times. If `n` is nil, repeat forever.
  * `until_success` / `until_failure`: tick until child yields the target result; then `SUCCESS`.
  * `wait(s)`: wait `s` seconds before ticking child once; then mirror child result.
  * `cooldown(s)`: after child `SUCCESS`, return `FAILURE` for `s` seconds. Good inside selectors to try alternatives.
  * `time_limit(s)`: if child runs longer than `s`, force `FAILURE`.

**Reset** means the subtree’s node memory is cleared and `abort` is called on running actions.

---

## 9. Scheduling strategies

* **Per‑entity**: `bt.instance(tree, { tick_interval = 0.05, stagger = true })`.
* **Global**: `bt.system{ interval = 0.05 }`.
* Prefer per‑entity for uneven loads, global for tight lockstep.

---

## 10. Debugging and introspection

```lua
local status = bt.last_status(entity)     -- root status
print(bt.dump_status(entity))             -- table of node statuses
```

Tips:

* Put prints in your leaves during bring‑up only. Remove for shipping.
* Build small trees first. Add branches after verifying basics.
* Use `cooldown` to prevent thrashing between selectors.

---

## 11. Performance checklist

* Keep leaf `tick` functions branch‑light.
* Avoid allocations in `tick`. Reuse `ctx.state` and pre‑create tables.
* Use `tick_interval` for AI that need not run every frame.
* Prefer conditions over actions when a check is instantaneous.
* Keep parallel fan‑out small when possible.

---

## 12. Determinism notes

* Staggering uses `math.random`. Set `math.randomseed(seed)` at startup if you need repeatable openings.
* Otherwise the tree evaluation is deterministic for a given sequence of inputs and `dt` slices.

---

## 13. Testing patterns

Minimal harness:

```lua
local tiny = require('tiny')
local bt   = require('tiny-bt')
local T    = bt.dsl

-- register leaves ... build tree ...
local e = {}
e.bt = bt.instance(tree)

local world = tiny.world(bt.system{})
world:addEntity(e)

for i=1,60 do tiny.update(world, 1/60) end
```

Unit testing a single action:

```lua
local calls = {}
bt.register_action('Probe', {
  start=function(ctx) calls[#calls+1]='start' end,
  tick=function(ctx, dt)
    calls[#calls+1]='tick'
    return (#calls > 3) and bt.SUCCESS or bt.RUNNING
  end,
  abort=function(ctx) calls[#calls+1]='abort' end,
})
```

Assert the sequence of calls and statuses.

---

## 14. Patterns

### Patrol → Chase → Attack

```lua
local tree = bt.build(
  T.selector{
    T.sequence{
      T.condition{ name='HasTarget' },
      T.parallel({
        T.action{ name='FaceTarget' },
        T.time_limit(1.0, T.action{ name='MoveTo', params={ stop_radius=1.5 } }),
      }, { success=2, failure=1 }),
      T.action{ name='Attack' },
    },
    T.cooldown(3, T.action{ name='Patrol' }),
    T.action{ name='Idle' },
  }
)
```

### Fallback with cooldowns

```lua
T.selector{
  T.cooldown(5, T.action{ name='HeavyShot' }),
  T.action{ name='LightShot' },
}
```

### Retry until success with a time budget

```lua
T.time_limit(2.0, T.until_success(T.action{ name='OpenDoor' }))
```

---

## 15. FAQ

**Q: Where do I store long‑lived AI state?**
Use components on the entity. `ctx.bb:set('waypoint', id)` for pointers; `ctx.state` only for transient action data.

**Q: How do I cancel an action when switching branches?**
Parents reset losing branches. Your action’s `abort` will run.

**Q: Can conditions read params?**
Yes. Check `ctx.params` if you passed them from the DSL.

**Q: How do I pause an NPC?**
Wrap the root in `T.selector{ T.condition{ name='IsPaused' } |> T.succeeder, <normal root> }` or gate important branches with `IsPaused`.

**Q: How do I run trees at different rates?**
Use `tick_interval` per entity. Optionally a global `system.interval` for everything.

---

## 16. Troubleshooting

* **"unregistered action/condition"**: name mismatch. Register before building entities.
* **Thrashing between branches**: add `cooldown`, or make conditions mutually exclusive.
* **Nothing happens**: ensure `world:addSystem(bt.system{})` and the entity has `bt` set.
* **High CPU**: add intervals, reduce parallel fan‑out, collapse cheap checks into conditions.

---

## 17. API surface

```lua
-- statuses
bt.SUCCESS; bt.FAILURE; bt.RUNNING

-- dsl
T.sequence{...}; T.selector{...}; T.parallel(children, opts)
T.condition{ name=..., params=? }
T.action{ name=..., params=? }
T.inverter(child); T.succeeder(child); T.failer(child)
T.repeat_n(child, n); T.until_success(child); T.until_failure(child)
T.wait(seconds, child); T.cooldown(seconds, child); T.time_limit(seconds, child)

-- build + instance
bt.build(rootSpec)          --> tree
bt.instance(tree, opts)     --> component for entity.bt
  -- opts: tick_interval?, stagger?, name?

-- system
bt.system{ filter?, interval? } --> tiny processingSystem

-- leaves
bt.register_condition(name, fn)
bt.register_action(name, { validate?, start?, tick, abort? })

-- bb helper (via ctx.bb)
:has(key) :get(key) :set(key, value)

-- introspection
bt.last_status(entity)  --> status or nil
bt.dump_status(entity)  --> string table of node states
```

---

## 18. License and attribution

Use at your discretion within your project. Credits to your ECS and game framework of choice.
