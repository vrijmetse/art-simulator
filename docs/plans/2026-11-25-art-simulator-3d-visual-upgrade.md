# ART Simulator — 3D Visual Upgrade (Three.js) Specification

**Goal:** Transform the ART Simulator's room rendering from procedural 2D shapes into interactive 3D environments using Three.js, leveraging CC0 3D furniture models. This will provide a more immersive and tactile experience while maintaining mobile-first performance and a cozy aesthetic.

## Architecture Overview
The core simulation logic (economy, jobs, i18n, save) will remain in pure TypeScript and remain engine-agnostic. The existing Phaser.js game will continue to manage the UI, transitions, and audio. The main change is that the `RoomScene` will render its primary UI/HUD and game elements in Phaser, but the 3D room background will be rendered by a Three.js scene onto a separate, transparent HTML `<canvas>` element layered *behind* Phaser's canvas. This Canvas Stacking approach avoids problematic WebGL context sharing issues.

## Key Technical Decisions

### 1. Rendering Integration (Canvas Stacking)
- A dedicated `<canvas id="three-layer">` sits behind Phaser's canvas (`transparent: true` on Phaser), with its CSS `left`, `top`, `width`, `height` synced to `phaserCanvas.getBoundingClientRect()` on every resize / `Scale.FIT` update.
- `renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))`, explicit `webglcontextlost` / `webglcontextrestored` handling, and dirty-flag on-demand rendering to conserve mobile battery.

### 2. 3D Model Sourcing & Pipeline
- **Models:** 42 curated low-poly CC0 1.0 `.glb` models from Kenney Furniture Kit v2.0 (`public/models/*.glb`, ~590 KB total across all 5 rooms!) + procedural low-poly fallbacks (`Box3` / custom hero props like Crown/Chalice/Scroll) if any fetch fails.
- **Caching:** `vite-plugin-pwa` caches `**/*.{js,css,html,svg,png,woff2,glb}` cleanly (`skipWaiting: true`, `clientsClaim: true`).
- **Credits:** `CREDITS.md` documents CC0 1.0 provenance.

### 3. 3D Scene Composition
- Each room (`JobSpec`) creates a Three.js `Scene` with warm cozy walls/floor/rug, shadow-casting `DirectionalLight` + `HemisphereLight`, CC0 furniture layout, and camera angle presets (`-28° / 0° / +28°` orbit button in HUD so players can rotate the 3D room!).

### 4. 3D Interaction Rework
- **Scrubbing (Stains):** Stains are `THREE.PlaneGeometry` decal quads with `polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1` + `0.008m` surface offset (eliminating Z-fighting), backed by offscreen 2D `<canvas>` `THREE.CanvasTexture` (`destination-out` erase, `needsUpdate = true` only when scrubbed) — zero cross-context GPU readbacks.
- **Clutter Drag & Snap:** Clutter items are 3D `.glb` meshes (or stylized 3D meshes). Dragging intersects an invisible horizontal plane at the item's `Y` elevation (`intersectRayPlane` in `src/core/math3d.ts`) clamped to room bounds, and snaps in 3D via `isWithin3DSnapRadius` using `ToolStats.snapRadius3D`.

### 5. Data Structure Updates (`src/core/types.ts`, `src/core/jobs.ts`, `src/core/economy.ts`)
- Backward-compatible optional 3D fields (`furnitureLayout?`, `pos3D?`, `targetPos3D?`, `rot3D?`, `size3D?`, `modelName?`, `scale3D?`) so all existing 2D unit tests stay green.
- `StainSpotSpec` uses a single orientation (`rot3D?`) — no redundant `normal` field.
- `ToolStats` includes explicit metric `brushRadius3D` and `snapRadius3D` alongside 2D values.

### 6. Integration Lifecycle & Memory Management
- `Room3DView` encapsulates Three.js scene/camera/renderer and attaches `destroy()` to `RoomScene`'s `shutdown` event: disposes every geometry, material, texture (`scene.traverse`), calls `renderer.dispose()`, removes DOM canvas, and cancels RAF.

### 7. Testability (TDD Strategy in Vitest / Node.js)
- Pure TypeScript `src/core/math3d.ts` (`screenToNDC`, `intersectRayPlane`, `worldHitToDecalUV`, `clampRoomXZ`, `distance3D`, `isWithin3DSnapRadius`) unit-tested 100% headlessly in `tests/core/math3d.test.ts` before writing 3D rendering code.
