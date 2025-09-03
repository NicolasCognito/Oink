# Composite Zones Proposal (Backward-Compatible)

## Goal

Evolve zones from a single axis-aligned rectangle to a composite shape made of one or more colliders, while remaining fully backward-compatible with existing rectangular zones.

- Preserve current API and behavior where `zone.rect` is the only shape.
- Add optional `zone.colliders` for complex shapes and sub-regions.
- Keep all existing systems working; enable new systems/behaviors to leverage multiple colliders cleanly.

## Backward Compatibility

- `zone.rect` remains required and acts as collider #0 (the "base" collider).
- If `zone.colliders == nil` or empty, logic uses only `zone.rect` (exactly as it does today).
- If `zone.colliders` is present, logic should consider collider #0 plus all additional colliders.

## Data Model

Base (legacy) collider (index 0):
- `zone.rect = { x, y, w, h }`

Composite colliders (index 1..N):
- `zone.colliders = { collider1, collider2, ... }`
- Each collider is relative to `zone.rect`'s origin `(rect.x, rect.y)`.
- Supported collider kinds (initial set):
  - Rect: `{ kind = 'rect', dx, dy, w, h }` (offset/size relative to base's top-left)
  - Circle: `{ kind = 'circle', dx, dy, r }` (center at `(rect.x + dx, rect.y + dy)`)

Optional metadata per collider:
- `id`: symbolic name (e.g., `'panel'`, `'teleport'`)
- `label`: short label for debug draw
- `flags`: table of booleans (e.g., `{ input=true, teleport=false }`) to filter collider usage per subsystem

Example:

```lua
local z = {
  zone = true,
  rect = { x=100, y=100, w=60, h=30 }, -- collider #0 (base)
  -- two extra colliders splitting the base: left = teleport, right = panel
  colliders = {
    { kind='rect', id='teleport', dx=0,       dy=0,  w=30, h=30 },
    { kind='rect', id='panel',    dx=30,      dy=0,  w=30, h=30 },
  },
}
```

A mixed shape:

```lua
colliders = {
  { kind='rect',   id='pad',   dx=0,  dy=10, w=60, h=10 },
  { kind='circle', id='halo',  dx=30, dy=15, r=22 },
}
```

## Collision Helpers (libs/collision.lua)

Augment the library to avoid spreading shape logic across systems:

- `rect_contains_point(rect, x, y)` (exists)
- `rects_overlap(a, b)` (exists)
- `rect_center(rect)` (exists)
- `circle_contains_point(cx, cy, r, x, y)` (new)
- `collider_contains_point(base_rect, collider, x, y)`
  - If `collider == nil`, test against `base_rect`.
  - If `kind=='rect'`, test `rect_contains_point({ x=rect.x+dx, y=rect.y+dy, w, h }, x, y)`
  - If `kind=='circle'`, test `circle_contains_point(rect.x+dx, rect.y+dy, r, x, y)`
- `zone_any_contains_point(zone, x, y, opts)`
  - Return true if inside collider #0 or any `zone.colliders`.
  - Optional `opts.filter`: predicate `(collider) -> bool` to restrict which sub-colliders count (e.g., only `id=='panel'`).

## Systems Impact (incremental, non-breaking)

Short term (optional, feature-by-feature):
- Zones system (`systems/zones.lua`):
  - For behaviors meant to trigger if inside any collider, use `zone_any_contains_point`.
  - For sub-region logic (e.g., teleporter left/right), filter by collider `id`.
- Input system (`systems/input.lua`):
  - When deciding the "active" zone for key handling, still pick the first overlapping zone but check composite colliders via `zone_any_contains_point` or a filtered region (e.g., `id=='panel'`).
- Drawing (`systems/draw.lua`):
  - Draw `zone.rect` as today.
  - If `zone.colliders`, additionally draw outlines for each sub-collider (thin/ghosted) and optional divider line for splits.

This can be adopted incrementally per zone without breaking existing content.

## Zone Authoring Pattern

- Use `zone.rect` to position the overall zone.
- Add local sub-colliders under `zone.colliders` for interactive regions or shape refinements.
- Optionally name them with `id`, and let zone code test for specific regions:

```lua
-- Example: inside panel region?
local function in_region(zone, id, x, y)
  if not zone.colliders then return false end
  for i = 1, #zone.colliders do
    local c = zone.colliders[i]
    if c.id == id and collision.collider_contains_point(zone.rect, c, x, y) then
      return true
    end
  end
  return false
end
```

## Migration Strategy

- No changes required to existing zones.
- As zones gain richer behavior (e.g., split teleporter), refactor their internals to check sub-colliders where applicable.
- Keep falling back to `zone.rect` for broad tests (e.g., labeling, visibility checks).

## Performance Considerations

- Most zones are static; computing absolute collider bounds is O(N) and cheap.
- If many zones become dynamic, consider caching absolute bounds and invalidating only when `zone.rect` changes.
- For heavy scenes, spatial indexing can be introduced later without changing the API.

## Testing Approach

- Add unit tests per shape helper (rect, circle, composite contain checks).
- Add behavior tests for zones that use split/regions (e.g., teleporter left/right).
- Maintain legacy tests to ensure single-rect zones behave unchanged.

## Future Extensions

- Additional shapes (capsule/line), polygon colliders, or path regions.
- Per-collider properties (e.g., `time_scale`, `damage`, `priority`) for richer effects.
- Authoring helpers (factory to generate symmetric splits, grids).
- Editor HUD overlays to visualize colliders and `id`s.

---

This plan keeps today’s zones working while enabling progressively richer shapes and sub-regions. Systems adopt the composite checks where it adds value, and legacy zones remain untouched.

