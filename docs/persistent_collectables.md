# Persistent Collectables (Non-Destructive Pickup)

This note explains a second class of collectables that are not meant to be destroyed on pickup. Instead of removing their entity from the world permanently, they are “deactivated” while carried and then reappear (reactivated) on drop. These items do not stack.

## Two Classes of Collectables

- Consumables (default today):
  - Example: `coin`, `egg`, `ruby`.
  - On pickup: the world entity is removed; inventory stores an abstract record `{ name, value }` and can stack by name.
  - On drop: a new item entity is spawned from the record.

- Persistent collectables (this doc):
  - Example: “loot zombie” or other unique objects that should come back as-is.
  - On pickup: the world entity is deactivated (out of play, not drawn/updated) but not destroyed; a reference to this entity occupies one inventory slot.
  - On drop: the exact same entity is reinserted/reactivated at the player’s position.
  - Non-stackable: each slot holds at most one persistent collectable reference.

## Lifecycle

1) Pickup
- Detect that the target collectable is persistent (e.g., `collectable.persistent == true`).
- Deactivate the entity:
  - Options: `world:remove(e)` while keeping a Lua reference, or mark `e.active=false`/`e.drawable=false` and let systems skip it.
- Store a slot payload that contains a direct reference to the entity (and optionally its metadata). Do not increment any name-based stack.

2) Inventory State
- Each slot may hold either:
  - A stackable record: `{ name, count, value }` (consumables), or
  - A persistent ref: `{ entity = <ref>, name = e.collectable.name }` (count is implied = 1).
- Capacity still counts 1 slot per item (whether stackable or persistent).

3) Drop
- If the active slot holds a persistent ref:
  - Place the same entity back into the world at the player’s position; mark it active/drawable again (or `world:add(e)`).
  - Clear the slot without compressing: set `slots[i] = nil` to leave a hole and preserve indices.
- If the active slot holds a stackable record:
  - Behaves as today: remove one count and spawn a new entity from `{ name, value }`.

## Non-Stacking Rule

- Persistent items represent a unique entity and cannot be merged with others. Treat the slot as “occupied by an object”, not a stack counter.
- The HUD can show these as `i:loot_zombie` (no `xN` suffix) to distinguish from stackable items.

## Backward Compatibility

- Default collectables remain consumable/stackable — no changes required to coins/eggs/rubies.
- Introduce persistence by adding a flag on the entity’s `collectable` component, e.g. `collectable = { name='zombie', value=5, persistent=true }`.
- Systems (collect, zone_collect) continue to work; only the inventory/drop path changes for persistent items.

## Suggested Flags & Checks

- On pickup:
  - If `it.collectable.persistent == true` then store as `{ entity = it, name = it.collectable.name }` and deactivate `it`.
  - Else, use the stackable flow (existing behavior).
- On drop:
  - If slot has `entity`, re-add/reactivate the entity instead of spawning a new one.

## Examples

- Loot Zombie (persistent):
  - Pickup: deactivates zombie entity; one slot shows `zombie`.
  - Drop: same zombie entity reappears at the player.
- Coins (consumable):
  - Pickup: world coin removed; `coin` stack increases.
  - Drop: coin entity is spawned from the stack record.

## Implementation Notes (when we wire it in)

- Inventory data structure: allow a slot to carry either a stack record or an entity ref; treat `slots` as a sparse array (holes allowed).
- Deactivate semantics: simplest is to `world:remove(e)` and rely on the slot holding the reference until re-adding it.
- Prevent re-collection races: when re-adding, consider a tiny invulnerability/timestamp to avoid immediate re-pickup on the same frame (or add on the next tick).
- HUD: render persistent slot as `name` without `xN` suffix; empty slots remain visible as holes to avoid shifting indices.

This design keeps current behavior for consumables and adds a clean, non-destructive flow for unique items that should return to the world exactly as they were before pickup.
