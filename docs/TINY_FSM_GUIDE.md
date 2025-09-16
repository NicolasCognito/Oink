# Tiny‑FSM for tiny‑ecs — Developer Guide

Finite State Machines for tiny‑ecs / LÖVE. Declarative states and transitions as data. One shared machine asset, tiny per‑entity runtime, single tiny processing system.

**Scope**: FSMs are for simple, mechanical, or ambient logic. Good for buildings in RTS, doors, traps, UI panels, timers, and background world actors. Do **not** use this plugin for agent AI. For agents and decision making, use your Behavior Trees plugin instead.

---

## 1. Install

1. Put `tiny-fsm.lua` somewhere on your Lua package path.
2. Require it where you set up your world:

```lua
local tiny = require('tiny')
local fsm  = require('tiny-fsm')
```

---

## 2. Quick start

````lua
-- 1) Register reusable logic for non‑agent actors
fsm.register_action('BootSequence', {
  enter=function(ctx) ctx.entity.boot_t = 0 end,
  update=function(ctx, dt)
    ctx.entity.boot_t = ctx.entity.boot_t + dt
    if ctx.entity.boot_t > 2 then return 'online' end
  end,
})

fsm.register_condition('HasPower', function(ctx)
  return ctx.entity.has_power == true
end)

-- 2) Build a shared machine asset for a building
local M = fsm.build({
  initial = 'offline',
  states = {
    offline = {
      transitions = { { if_='HasPower', to='booting', priority=10, interrupt=true } }
    },
    booting = {
      action = 'BootSequence',
    },
    online = {
      on_update = function(ctx, dt)
        -- produce resources while online
        ctx.entity.stock = (ctx.entity.stock or 0) + dt * (ctx.entity.rate or 1)
        if not ctx.entity.has_power then return 'offline' end
      end
    },
  }
})

-- 3) Attach per‑entity runtime to a building entity
plant.fsm = fsm.instance(M, { tick_interval=0.05, stagger=true, name='PlantFSM' })

-- 4) Add the system once
world:addSystem(fsm.system{}) -- default filter: entities with field `fsm`
```lua
-- 1) Register reusable logic
fsm.register_action('Chase', {
  enter=function(ctx) ctx.entity.animation='run' end,
  update=function(ctx, dt)
    local e, p = ctx.entity, ctx.world.player
    local dx = p.position.x - e.position.x
    e.velocity.x = dx > 0 and 60 or -60
  end,
  exit=function(ctx) ctx.entity.velocity.x = 0 end,
})

fsm.register_condition('SeePlayer', function(ctx)
  local e, p = ctx.entity, ctx.world.player
  return math.abs(p.position.x - e.position.x) < 160
end)

-- 2) Build a shared machine asset
local M = fsm.build({
  initial = 'idle',
  states = {
    idle = {
      on_enter = function(ctx) ctx.entity.animation='idle' end,
      transitions = {
        { if_='SeePlayer', to='chasing', priority=10 },
      }
    },
    chasing = {
      action = 'Chase',
      transitions = {
        { if_=function(ctx) return not fsm.call('SeePlayer', ctx) end, to='idle' },
      }
    },
  }
})

-- 3) Attach per‑entity runtime
enemy.fsm = fsm.instance(M, { tick_interval=0.05, stagger=true, name='EnemyFSM' })

-- 4) Add the system once
world:addSystem(fsm.system{}) -- default filter: entities with field `fsm`
````

---

## 3. Concepts

* **Machine asset**: immutable state graph shared by all entities.
* **Per‑entity instance**: tiny table that stores current/previous state, timers, and a small event queue.
* **Tick**: system drives the active state, checks interrupts, runs `update`, then normal transitions.
* **Actions & conditions**: registered once by name and reused across machines.

---

## 4. ECS wiring

```lua
local sys = fsm.system{
  -- filter = tiny.requireAll('fsm'), -- default
  -- interval = 0.016,               -- optional global cadence
}
world:addSystem(sys)
```

Per‑entity cadence:

```lua
entity.fsm = fsm.instance(M, { tick_interval = 0.1, stagger = true })
```

* `tick_interval`: time slice for this entity only. If nil, ticks every frame.
* `stagger`: randomizes first tick to avoid spikes. Seed `math.randomseed(...)` if you want deterministic staggering.

---

## 5. The context object (`ctx`)

Provided to actions and conditions:

| Field        | Meaning                                   |
| ------------ | ----------------------------------------- |
| `world`      | tiny world                                |
| `entity`     | current entity                            |
| `state_name` | string of current state                   |
| `params`     | transition‑provided params if any         |
| `next_event` | the pending `{name, data}` tuple or `nil` |

Helpers:

```lua
fsm.call('ConditionName', ctx)  -- invoke a registered condition by name
```

---

## 6. State spec

`fsm.build(spec)` where `spec`:

```lua
{
  initial = 'idle',
  states = {
    [name] = {
      -- Logic (either inline or via action)
      action    = 'RegisteredActionName', -- optional shortcut
      on_enter  = function(ctx) end,      -- optional
      on_update = function(ctx, dt) end,  -- optional; may return a state name to jump
      on_exit   = function(ctx) end,      -- optional

      -- Transitions
      transitions = {
        { if_ = 'RegisteredCondition' | function(ctx)->bool,
          to = 'state_name',
          priority = 0,           -- higher first
          interrupt = false,      -- checked before update when true
          params = any            -- copied into ctx.params when evaluated
        },
        -- ...
      }
    },
    -- ... more states ...
  }
}
```

Notes:

* If both `action` and explicit hooks are present, explicit hooks win.
* `on_update` may return a target state name; this overrides normal transitions that tick.
* Transitions are checked in two passes: all `interrupt=true`, then `on_update`, then the rest.

---

## 7. Registries

```lua
fsm.register_action(name, {
  enter=function(ctx) end,
  update=function(ctx, dt) end,
  exit=function(ctx) end,
})

fsm.register_condition(name, function(ctx) return true end)
```

Keep actions and conditions side‑effect free except for writing to the entity.

---

## 8. Transition semantics

* **Interrupts** run before `on_update`. Use for urgent changes like alarms or power loss.
* **Priority** sorts transitions within each state (desc).
* **Params** are exposed at evaluation time via `ctx.params`.
* External overrides:

  * `fsm.set(entity, 'state')` schedules a hard switch at end of tick.
  * `on_update` returning a valid state switches immediately.

---

## 9. Scheduling strategies

* **Per‑entity**: `fsm.instance(M, { tick_interval = 0.05, stagger = true })`.
* **Global**: `fsm.system{ interval = 0.05 }`.
* Prefer per‑entity for uneven loads; use global for strict lockstep.

---

## 10. Events and external control

Push events from other systems and read them in conditions or `on_update`:

```lua
fsm.push_event(entity, 'damaged', { amount = 5 })
-- inside update/condition
local name, data = fsm.pop_event(entity)  -- marks head as consumed for this tick
```

Event queue is tiny and auto‑compacts after consumption. Use sparingly.

---

## 11. Debugging and introspection

```lua
print(fsm.dump(entity))      -- one‑line summary
print(fsm.state(entity))     -- current state name
```

Tips:

* Print in actions during bring‑up only. Remove later.
* Start simple. Add transitions after basics work.

---

## 12. Performance checklist

* Keep `on_update` branch‑light. Avoid allocations.
* Reuse per‑entity tables inside the instance. Let the system handle cadence.
* Use `interrupt` only when needed; it adds checks every tick.
* Prefer conditions over heavy `on_update` logic when checks are instantaneous.

---

## 13. Determinism notes

* Staggering uses `math.random`. Seed if you need repeatable openings.
* Otherwise evaluation is deterministic for a given input stream and `dt` slices.

---

## 14. Testing patterns

Minimal harness:

```lua
local tiny = require('tiny')
local fsm  = require('tiny-fsm')

-- register actions and conditions, build machine ...
local e = {}
e.fsm = fsm.instance(M)

local world = tiny.world(fsm.system{})
world:addEntity(e)

for i=1,60 do tiny.update(world, 1/60) end
```

Unit‑test an action:

```lua
local calls = {}
fsm.register_action('Probe', {
  enter=function(ctx) calls[#calls+1]='enter' end,
  update=function(ctx, dt)
    calls[#calls+1]='update'
    if #calls > 3 then return 'done' end -- cause a transition by name
  end,
  exit=function(ctx) calls[#calls+1]='exit' end,
})
```

---

## 15. Patterns

### Power grid building

```lua
local M = fsm.build({
  initial='off',
  states={
    off={
      transitions={ {if_=function(ctx) return ctx.entity.has_power end, to='boot', interrupt=true} }
    },
    boot={
      on_enter=function(ctx) ctx.entity.boot_t=0 end,
      on_update=function(ctx, dt)
        ctx.entity.boot_t = ctx.entity.boot_t + dt
        if ctx.entity.boot_t>2 then return 'on' end
      end,
    },
    on={
      transitions={ {if_=function(ctx) return not ctx.entity.has_power end, to='off', priority=10} }
    },
  }
})
```

### Trap with cooldown

```lua
local M = fsm.build({
  initial='armed',
  states={
    armed={ transitions={ {if_=function(ctx) return ctx.entity.triggered end, to='firing', interrupt=true} } },
    firing={ on_enter=function(ctx) ctx.entity.anim='shoot' end,
             on_update=function(ctx, dt) if ctx.entity.anim_done then return 'cooldown' end end },
    cooldown={ on_enter=function(ctx) ctx.entity.cool=1 end,
               on_update=function(ctx, dt) ctx.entity.cool = ctx.entity.cool - dt; if ctx.entity.cool<=0 then return 'armed' end end },
  }
})
```

### Door controller

```lua
local Door = fsm.build({
  initial='closed',
  states={
    closed={ transitions={ {if_=function(ctx) return ctx.entity.open_signal end, to='opening', interrupt=true} } },
    opening={ on_update=function(ctx, dt) ctx.entity.pos = math.min(1, (ctx.entity.pos or 0)+dt*2); if ctx.entity.pos>=1 then return 'open' end end },
    open={ transitions={ {if_=function(ctx) return ctx.entity.close_signal end, to='closing', interrupt=true} } },
    closing={ on_update=function(ctx, dt) ctx.entity.pos = math.max(0, (ctx.entity.pos or 1)-dt*2); if ctx.entity.pos<=0 then return 'closed' end end },
  }
})
```

---

## 16. FAQ

**Q: Why not use FSMs for agents?**
BTs handle decision making and long‑running actions better. FSMs are for simple ambient logic and will become brittle for agents.

**Q: Can I run multiple FSMs on one entity?**
Yes. Store them under different fields, e.g. `entity.power_fsm`, and add a custom `filter` or a wrapper.

**Q: How do I pause an object?**
Gate transitions with a `IsPaused` condition or override with `fsm.set(e, 'paused')`.

**Q: Can transitions modify components?**
Do it in `on_exit`/`on_enter` or the next state's first `on_update`.

---

## 17. API surface

```lua
-- build + instance
fsm.build(spec)                 --> machine asset
fsm.instance(asset, opts)       --> component for entity.fsm
  -- opts: tick_interval?, stagger?, name?

-- system
fsm.system{ filter?, interval? } --> tiny processingSystem

-- registries
fsm.register_action(name, { enter?, update?, exit? })
fsm.register_condition(name, fn)
fsm.call('ConditionName', ctx)

-- external control
fsm.set(entity, 'state')
fsm.push_event(entity, name, data)
fsm.pop_event(entity)              --> name, data | nil

-- introspection
fsm.state(entity)   --> current state string or nil
fsm.dump(entity)    --> single‑line summary
```

---

## 18. Domain separation from BT

* **BT (agents, "intelligent")**: Planning, goal selection, long‑running actions, interrupts, recovery.
* **FSM (ambient, "dumb")**: Switches, machines, traps, UI, buildings, world simulation. Keep it mechanical. Avoid on agents.

If you need both, run BT for the agent and let it toggle FSM‑driven props around it.
