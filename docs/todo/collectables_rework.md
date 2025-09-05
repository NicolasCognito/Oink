# Collectables Rework: Tag-based Matching with Whitelist/Blacklist

Goal: allow entities to be both collectors and collectables safely by matching on tags instead of hardcoded names, and by supporting per-collector allow/deny rules.

## Motivation
- The player may need to be a collectable (e.g., as a car passenger) while also being a collector (picking up coins, etc.). Current name-based checks and boolean flags make this awkward and error-prone (e.g., self-collect).
- Systems should remain generic: collectors decide what to pick up based on tags rather than special cases.

## Core Idea
- Add tags to collectables: `collectable.tags = { 'coin', 'stackable', 'passenger', ... }`.
- Add per-collector policy:
  - `collector.whitelist = { 'coin', 'ruby', 'work', ... }` (optional)
  - `collector.blacklist = { 'passenger', ... }` (optional)
- Matching rule:
  - Allowed if (`collectable.tags` intersects `whitelist`) OR `whitelist` omitted/empty (means “any”).
  - AND disallowed if (`collectable.tags` intersects `blacklist`). Blacklist always wins.
- Self-collection safety:
  - A collector can explicitly blacklist tags it carries (e.g., `passenger`) to avoid self-collect when it is also a collectable.

## Defaults
- Backward compatibility: if no tags/policies provided, maintain current behavior (e.g., accept via existing `accept_collectable` predicate or default name checks).
- New generic accept function (opt-in):
  - `accept_collectable(self, item)` returns true/false based on tags and whitelist/blacklist.

## Example: Player and Car
- Player entity:
  - `player.collectable = { name='player', value=0, tags={'passenger'} }`
  - `player.collector = true`
  - `player.whitelist = { 'coin', 'ruby', 'egg' }`
  - `player.blacklist = { 'passenger' }` (prevents picking up themselves or other passengers)
- Car entity:
  - `car.collector = true`
  - `car.whitelist = { 'passenger' }`
  - `car.blacklist = {}`
  - Car can pick up entities tagged as `passenger` (e.g., player), while players won’t.

## System Changes (high-level)
- `systems/collect.lua` and `systems/zone_collect.lua`:
  - If a collector defines `whitelist`/`blacklist`, use the tag-based matcher.
  - Otherwise, fall back to existing `accept_collectable` or name-based logic.
- Inventory:
  - Unchanged. Tag logic only affects acceptance, not storage.
- UI/HUD:
  - Optional: show tags for debugging or policy misconfigurations.

## API Sketch
- Collectable:
  - `e.collectable = { name='coin', value=1, tags={'coin','stackable'} }`
- Collector:
  - `e.collector = true`
  - `e.whitelist = { 'coin', 'passenger' }` -- optional
  - `e.blacklist = { 'passenger' }` -- optional
- Helper:
  - `tags.match(collectable_tags, whitelist, blacklist)` returns bool

## Matching Logic (pseudo)
```
function accept_by_tags(collector, item)
  local ct = (item.collectable and item.collectable.tags) or {}
  local wl = collector.whitelist
  local bl = collector.blacklist
  local has = function(set, tagset)
    if not set or #set == 0 then return false end
    local map = {}
    for _,t in ipairs(set) do map[t]=true end
    for _,t in ipairs(tagset) do if map[t] then return true end end
    return false
  end
  if bl and has(bl, ct) then return false end
  if (not wl) or #wl==0 then return true end
  return has(wl, ct)
end
```

## Migration Strategy
- Phase 1 (opt-in): add tags to select collectables and policies to select collectors (e.g., car/passenger).
- Phase 2: gradually replace custom `accept_collectable` where appropriate with the generic tag matcher.
- Phase 3 (optional): provide a debug overlay to visualize why an item was/wasn’t accepted.

## Edge Cases
- Items without tags: treated as empty tag set; only collected if whitelist is empty or a legacy accept function allows it.
- Overlapping policies: blacklist always overrides whitelist.
- Self-collection: ensure entity identity checks still guard against collecting itself even if tags match.

## Notes
- This design keeps current behavior working and provides a flexible path to richer interactions without special cases.
- We should be careful to not regress performance; tag checks are simple set intersections and run only when overlapping.

