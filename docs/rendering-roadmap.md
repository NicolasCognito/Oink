# Rendering & UX Roadmap

This doc gathers near-term ideas for improving rendering and UX. No code here — just goals, design, and light API sketches for alignment.

## Canvas Minimap
- Goal: Downscaled view of the world rendered into a corner overlay.
- Why: Spatial awareness, debugging, and future gameplay (e.g., pings).
- Design
  - Offscreen rendering to a persistent Canvas (avoid per-frame create).
  - Draw only world/agents; keep UI separate.
  - Optional markers (player, objectives).
- API Sketch
  - draw/canvas.lua helper
    - get(key, w, h, opts) → persistent canvas
    - with(canvas, fn) → bind/clear/draw/restore
    - invalidate(key), resize(key, w, h), free(key)
  - Minimap module
    - minimap.update(dt) sets dirty on interval or world changes
    - minimap.draw(gfx, x, y, scale) draws the last rendered canvas
- Integration
  - UI layer handler draws the canvas at top-right with padding
  - Optional: keyboard toggle and zoom in dev builds
- Risks
  - Device/pixel ratios and MSAA differences; keep formats simple (default)

## Composer Guardrails
- Goal: Dev warnings when composition leaves entities under-handled.
- Why: Catch missing behavior early; clarify expectations.
- Design
  - After profiles.ensure(e), run checks:
    - Controllable entity without any input_handlers
    - Drawable entity/zone without any draw_handlers AND no e.draw
  - Emit concise warnings (once per entity signature) in dev mode
- API Sketch
  - Extend systems/composer.lua with warn_once(entity, signature, message)
  - Optionally attach e._compose_warnings = { ... } for HUD display
- Integration
  - No behavior change in release; gated behind DEBUG or config flag

## Camera / Viewport
- Goal: Simple camera for pan/zoom of world layers; UI unaffected.
- Why: Readability, presentation, and dev navigation.
- Design
  - Camera module with set(x,y,scale), push(), pop()
  - Apply camera to background, zones, world; reset for overlay, ui
- API Sketch
  - camera.set(x, y, scale)
  - camera.apply_world(gfx) and camera.reset(gfx)
- Integration
  - Draw system wraps world layer execution with camera transforms
  - Optional dev controls: WASD pan, +/- zoom, 0 reset
- Risks
  - Keeping entity-space math independent from camera transforms

## Draw Caching (Static Layers)
- Goal: Cache rarely changing layers to a canvas to reduce draw cost.
- Why: Zones/background are often static; avoid re-issuing draw calls.
- Design
  - Maintain per-layer canvas and a dirty bit
  - Invalidate on world add/remove/modify that affects the layer
  - Redraw cached canvas only when dirty; composite with dynamic layers
- API Sketch
  - cache.begin(layer), cache.end(layer) → internal; or cache.draw(layer)
  - cache.invalidate(layer) on entity lifecycle events
- Integration
  - Start with zones layer; measure, then extend to background
- Risks
  - Complexity of precise invalidation; begin with coarse invalidation then refine

## Post-Processing (Optional Later)
- Goal: Visual polish — bloom, CRT, color grading.
- Design
  - Render whole world to a canvas, then run a shader pass
- Risks
  - Shader portability and perf on low-end devices

---

## Next Steps
- Choose one track to implement first (minimap or camera are the least invasive)
- Agree on acceptance criteria (e.g., minimap clarity, camera controls)
- Land small PRs with toggles; iterate with measurements

