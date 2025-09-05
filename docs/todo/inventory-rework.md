# Inventory Rework (ECS-Aligned) — Discussion Notes

## Context
- Today, inventories are plain tables attached to entities (e.g., player) and operated via `libs/inventory.lua` with systems calling its API.
- Recent bugs (e.g., reserved slot label flipping to collected entity name like "zombie: x0") highlight coupling and ad-hoc owner logic.
- Goal: evaluate migrating to an ECS-native model (components + systems + queries) with clear ownership relations and reusable policies.

## Arguments For Change
- Separation of concerns: Inventory as data; behavior in systems; fewer owner-specific code paths.
- Relational clarity: Represent containment as `Contained(owner, slot_id)`; easy queries like "what’s in player slot 2?" and robust transfers.
- Policy reuse: Shared policy objects/functions (whitelist/blacklist/where) for collectors and slot acceptance, instead of ad-hoc `accept_collectable`.
- Extensibility: Vehicles/passengers, containers-in-containers, trading, and transfer rules become natural with components and queries.
- Testability: Unit-test an `inventory_system` in isolation; fewer hidden dependencies than mutating owner tables.

## Arguments Against Change
- Working baseline: Current implementation passes the test suite (including reserved-slot and label fixes).
- Rewrite cost: Touches `collect.lua`, `input_inventory.lua`, `draw.lua`, player construction, and zones with inventories.
- Regression risk: HUD, drop/transfer, zone flows must switch to relation-based queries; edge cases may be missed.
- Complexity overhead: ECS relations add indirection; current table-based approach is simple for a small demo.
- Perf surprises: Poorly scoped queries could regress perf if not event-driven and filtered by owner.

## Middle Ground (Incremental Path)
- Externalize config: Move player’s slot layout and accept policies into a `SlotConfig` component; keep `libs/inventory` façade initially.
- Introduce relations: Add a `Contained` relation (owner, slot_id, stack_key), run an `inventory_system` that mirrors today’s behavior.
- Policy module: Implement `entity_match.matches` and a policy builder; keep honoring existing `accept_collectable` for back-compat.
- Dual-run phase: Keep table inventory in sync with `Contained` until consumers (HUD, input, zones) switch to relations, then retire the table.

## Proposed ECS Design
- Components
  - `Inventory`: capacity, slot schema reference, aggregates (optional cache: counts per stack_key).
  - `Slot`: declarative schema (index, label, accept policy, stacking rules, max count) stored on the owner or as data on `Inventory`.
  - `Contained`: on item entities; fields `{ owner, slot_id, stack_key }`.
  - `Policy` (optional): reusable objects/functions for acceptance (`whitelist`, `blacklist`, `where`).
- Systems
  - `inventory_system`: processes add/remove/transfer events, enforces slot acceptance, updates `Contained` and aggregates.
  - `collect`: delegates acceptance to policy/slot selection; sets `Contained` on persistent items or aggregates records for non-entities.
  - `input_inventory`: interprets selection and drop requests; emits removal events; relies on `Contained` and aggregates.
  - `draw`: renders from `Contained` (per owner) and aggregates; no direct reads of owner tables.
- Policy/Matcher
  - `libs/entity_match.lua`: `matches(item, policy)` supporting function policies and `{all_of, any_of, none_of, where}`.
  - `build_query(policy)`: optional helper to produce `collect_query(c, ctx)` for ECS-native filtering.

## Migration Plan
- Phase 0: Guardrails
  - Add specs for HUD rendering, drop flow, zone transfers, and reserved-slot semantics (current behavior baseline).
- Phase 1: Policy module
  - Add `entity_match.matches` + tests; keep current collectors and inventory API unchanged.
- Phase 2: Slot schema externalization
  - Introduce `SlotConfig` component or data on `Inventory`; move player’s slot rules out of constructor logic.
- Phase 3: Relations + system
  - Add `Contained` and `inventory_system` that mirrors current add/remove; adapt `draw` to prefer relations (feature flagged).
  - Keep `libs/inventory` API but make it emit relation updates; maintain both until parity proven.
- Phase 4: Consumers switch-over
  - Update `collect`, `input_inventory`, and zones to use events/relations; retire direct table reads.
- Phase 5: Cleanup
  - Remove legacy table-only branches once tests pass; keep `Inventory` as a slim façade if useful.

## Decision Triggers
- Feature pressure: seats/passengers, shared/portable containers, trade, or per-slot dynamic rules across many entities.
- Coupling pain: repeated bugs or special-casing in player-specific inventory logic.
- Reuse demand: zones/NPCs need the same inventory semantics without code duplication.

## Risk Mitigations
- Event-driven updates: apply inventory changes on events, not per tick.
- Compatibility shims: keep `Inventory.add/remove/transfer` public API during migration.
- Scoped queries: always filter `Contained` by `owner` (and optional `slot_id`) to avoid full scans.
- Perf checks: micro-benchmarks for add/remove/transfer and HUD queries.

## Acceptance Criteria (for migration completion)
- Reserved slots: labels and accept policies behave identically pre/post migration.
- HUD: identical rendering for counts/values and entity presence per slot.
- Collection/Drop: parity in behavior and timing; no regressions in tests.
- Zones: vault/mine/token flows operate unchanged from a player perspective.

## Open Questions
- Do we keep non-entity records as aggregate counters on `Inventory` or instantiate transient entities for everything?
- How to express stacking policy generically (by name, by stack_key predicate)?
- Ownership cycles: should nested containers be allowed? If yes, depth limit?
- Save/load implications for `Contained` relations and aggregates.

## Current State References
- Player inventory and slot rules: `src/components/player.lua`
- Inventory ops: `libs/inventory.lua`
- Collection: `src/systems/collect.lua`
- Input & drop: `src/systems/input_inventory.lua`
- HUD: `src/systems/draw.lua`
- Zones using inventories: `src/Zones/vault.lua`, `src/Zones/token_mine.lua`, `src/Zones/main_hall.lua`

