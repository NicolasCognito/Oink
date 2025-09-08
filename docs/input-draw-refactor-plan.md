# Input & Draw Refactor Plan (Reset Notes)

This document captures problems observed during the previous refactor attempt and proposes a clean, minimal design that keeps logic in systems, improves clarity, and avoids hidden fallbacks.

## Problems (Symptoms)
- Diluted responsibilities:
  - `systems/input.lua` drifted into computing the active zone; that belongs in Context.
  - Per‑frame attachment of handlers made behavior implicit and surprising.
- Hidden fallbacks mask errors:
  - Input computed active zones if Context wasn’t present; deprecated shims let tests pass through legacy paths.
  - Specs sometimes omitted Context, forcing workarounds in Input.
- Inconsistent zone input model:
  - Mix of `on_key`, `on_mode_switch`, and `on_input` across zones.
- Draw pipeline is ad‑hoc:
  - Zones and entities can’t opt into custom rendering cleanly; no layer registry or explicit DrawContext.
- Test fragility:
  - Tests passed via shims/fallbacks that didn’t reflect runtime behavior.

## Goals
- Single source of truth for frame state in Context; systems remain thin and focused.
- Explicit, handler‑based input and draw; no per‑frame composition.
- No legacy fallbacks or shims; tests exercise the real code paths.
- Deterministic zone input selection (composite colliders + priority).
- Clear layering and an optional camera for draw.

## Target Architecture

### Systems Order
1. Context (first)
2. Input (pure dispatcher)
3. Zones (tick behaviors)
4. ZoneCollect → Agents → Move → Bounds → Collectables → Expiry → Collect → CarControl → Destroyer → Spawner

### Context Provider (authoritative)
- Builds snapshot each frame: `{ world, dt, agents, collectables, zones, coins, players }`.
- Sets `snapshot.active_avatar` (fallback: set first controllable via `avatar.candidates` if none controlled).
- Computes `snapshot.active_zone` and `snapshot.active_zones`:
  - Use `collision.zone_any_contains_point(zone, px, py)` (supports composite colliders).
  - Choose highest `zone.input_priority` for `active_zone`; tie‐break by entity order.

### Composer (one‑time attachment)
- New system that runs before Input; attaches handlers once per entity:
  - `input.profiles.ensure(e)` (movement: character/vehicle; inventory; mount for players).
  - `draw.profiles.ensure(e)` (zone outlines; default circle; wrap `e.draw` if present).
- Idempotent: can safely re‑run when components change; avoids per‑frame attachment in other systems.

### Input (pure dispatcher)
- Builds `InputState` (held/pressed/released, move axis, repeat).
- Reads `snapshot.active_avatar` and `snapshot.active_zone` from Context.
- Dispatches to handlers:
  - Actor: `who.input_handlers` in order.
  - Zone: `active_zone.input_handlers` + `active_zone.on_input` if present.
- No computation of active zones. No fallbacks. No deprecated systems.

### Zones (mode standardization)
- Mode‑capable zones expose `modes` (active = `modes[1]`).
- Generic `zone_mode` handler rotates Q/E and calls `zone._on_mode_change(prev, next, ctx)`.
- Zones implement `_on_mode_change` to apply semantics (e.g., time scale/labels). No `on_key`/legacy routing.

### Draw (handler‑based)
- Draw profiles attach defaults once; entities/zones can provide custom `draw_handlers`.
- Draw module gathers drawcalls, sorts by `layers` (background < zones < world < overlay < ui), executes.
- Provide `DrawContext` (`{ world, dt, camera, debug }`); apply camera for world layers, reset for UI.

## Data Contracts
- Snapshot fields from Context:
  - `active_avatar`, `players`, `agents`, `collectables`, `zones`, `coins`, `active_zone`, `active_zones`, `dt`.
- Input handlers: `{ channel='actor'|'zone'|'global', kind, on(self, who, ctx, input, dt) }`.
- Draw handlers: `{ layer, order, kind, draw(self, gfx, ctx) }`.

## Migration Plan (Clean Reset)
1. Make Context mandatory in all worlds/tests; run it first.
2. Move active zone computation into Context exclusively.
3. Remove all input fallbacks; Input becomes pure dispatcher.
4. Introduce Composer; remove per‑frame `profiles.ensure` calls from Input/Draw.
5. Standardize zones:
   - Use `modes` + `zone_mode` + `_on_mode_change`; remove `on_key`/legacy fallbacks.
   - Teleport/EmptyArea implement `on_input` directly for custom keys.
6. Draw: adopt handler pipeline and layer registry; add draw profiles.
7. Remove deprecated `systems/input_*` and update specs accordingly.
8. Add dev‑time guardrails:
   - Warn if controllable entities have no input handlers after composition.
   - Warn if drawable entities/zones have no draw handlers.
9. Tests:
   - Ensure all specs include Context and set an active avatar when needed.
   - Cover: vehicle movement, zone priority, mode rotation, teleport `on_input`.

## Risks & Mitigations
- Risk: Behavior changes due to ordering.
  - Mitigation: Keep ordering explicit; add small, focused specs for Input/Context interplay.
- Risk: Zones relying on `on_key` break.
  - Mitigation: Convert to `on_input` or `modes` pattern; provide examples in docs.

## Worklist (Implementation Outline)
- Add `src/systems/composer.lua` and wire before Input.
- Context: finalize `active_zone/active_zones` computation (priority + composite colliders).
- Input: strip any fallback computations; dispatch only.
- Draw: add `libs/draw/layers.lua`, ensure `libs/draw/profiles.lua` is used by Composer.
- Zones: convert to `modes + _on_mode_change` and/or `on_input`; remove `on_key` routes.
- Remove deprecated `systems/input_*` and update specs accordingly.

---

This plan centralizes logic in systems, eliminates hidden fallbacks, and keeps input/draw flexible via explicit, composable handlers. It also makes tests meaningful by exercising the same paths as runtime.


## Current Status Check (code audit)
- Context: `src/systems/context_provider.lua`
  - Computes `snapshot.active_avatar`, `active_zone`, and `active_zones` using composite colliders and priority. Good.
  - Provides collections (`agents`, `collectables`, `zones`, `coins`) and a `query` helper. Good.
- Input: `src/systems/input.lua`
  - Builds `InputState` via `libs/input/helpers.lua`. Good.
  - Dispatches to `who.input_handlers` and zone handlers (`input.handlers.*`). Good.
  - Still performs a fallback scan of `snapshot.zones` to derive overlapped zones when `active_zone(s)` missing. Plan: remove after all specs/worlds include Context.
  - Calls `input.profiles.ensure(who)` each frame. Plan: move to Composer.
- Draw: `src/systems/draw.lua`
  - Gathers per-entity draw handlers, sorts by layers (background < zones < world < overlay < ui), executes. Good baseline.
  - Calls `draw.profiles.ensure(e)` per entity per frame. Plan: move to Composer.
  - Passes `{ world }` as draw context; camera not yet integrated. Optional future.
- Profiles & Handlers:
  - Input profiles and handlers exist in `libs/input/*` (character, vehicle, inventory, mount, zone_mode). Good.
  - Draw profiles exist in `libs/draw/profiles.lua` (zone outlines, generic circle, custom wrapper). Good.
- Zones:
  - `Zones/time_vortex.lua` and `Zones/main_hall.lua` use `input.handlers.zone_mode`. Good.
  - `Zones/teleport.lua` and `Zones/empty_area.lua` implement `on_input`. Good.
- World order: `src/world.lua`
  - Runs `Context()` then `Input()` then zones and others. Good. No Composer yet.

## Action Items (surgical changes)
- Add Composer: `src/systems/composer.lua`
  - On process: iterate entities, call `input.profiles.ensure(e)` and `draw.profiles.ensure(e)` once per entity; idempotent.
  - Insert in `src/world.lua` before `Input()`.
- Input cleanup: `src/systems/input.lua`
  - Remove fallback block that scans `snapshot.zones` when `active_zone(s)` is absent.
  - Keep only: build `InputState`, resolve `who`, dispatch handlers, commit.
- Draw cleanup: `src/systems/draw.lua`
  - Remove per-frame `Profiles.ensure(e)` calls (Composer now handles).
  - Consider extending DrawContext to `{ world, dt, camera, debug }` (optional).
- Tests/specs:
  - Ensure all specs include `Context()` and set an active avatar when relevant.
  - Add/adjust specs for: vehicle movement, zone priority selection, mode rotation, teleport `on_input`.

Note: After Composer lands and specs are updated, removing Input/Draw fallbacks will align runtime and test behavior and simplify reasoning about active zones and handlers.
