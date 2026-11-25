# 3D Homekeeper Character & Tool Animation Plan

**Goal:** Add an articulated, cozy stylized 3D Homekeeper character (`HomekeeperRig`) to both `RoomScene` (cleaning/tidying contracts) and `PersonalRoomScene` (player's personal Kos room) with smooth walking, `Lap` vs `Pel` tool animations, celebration jump on 100% completion, and zero interference with touch raycasting or furniture collision.

## Architecture
1. **Pure Core Character State & Safe Positioning (`src/core/character.ts` — TDD):**
   - `CharacterPose = 'idle' | 'walk' | 'scrub' | 'celebrate'`
   - `CharacterMotionState { x: number; z: number; targetX: number; targetZ: number; rotY: number; pose: CharacterPose; animTime: number; scrubTimer: number }`
   - `createCharacterState(startX, startZ): CharacterMotionState`
   - `computeSafeStandPoint(actionX, actionZ, footprints, halfBounds = 2.05): [number, number]`
     - Offsets away from `actionX, actionZ` (e.g. `0.65m` toward open room center/front-right) and pushes outside any `FURNITURE_FOOTPRINTS` AABB (`padding = 0.25m`) + `clampRoomXZ` so the Homekeeper never stands inside beds, desks, or walls.
   - `stepCharacterMotion(state, dtSec): CharacterMotionState`
     - Smoothly moves toward `(targetX, targetZ)` at `2.4 m/s`, rotates `rotY` smoothly toward movement/action direction, transitions `walk -> idle` on arrival, decays `scrubTimer` (`scrub -> idle`), and returns `needsFrame: boolean` (keeps `dirty = true` in `Room3DView` while walking/scrubbing/celebrating, and idles cleanly at low frequency or gentle breathing).

2. **3D Stylized Articulated Rig (`src/game/homekeeper3d.ts`):**
   - Modular Three.js group (~`0.95m` tall cozy chibi proportions so she fits naturally beside `0.75m` desks & `0.5m` beds without blocking the camera!):
     - Grounded contact shadow disc + `leftLeg` / `rightLeg` pivots
     - Torso + cozy apron (terracotta `#E07A5F` + cream `#FDF6EC` collar)
     - Head + expressive eyes + warm cheeks + cozy sage headscarf/cap (`#81B29A`)
     - `leftArm` + `rightArm` pivots; `rightHandSlot` holds swappable **`Lap`** (folded blue/sage microfiber cloth) or **`Pel`** (wooden mop handle + fringe head) synced with `Room3DView.setToolMode()`.
   - `applyHomekeeperPose(rig, motionState, toolMode)` updates joint rotations (`armSwing`, `legSwing`, `scrubSweep`, `celebrateHop`), zero allocations per frame.
   - All meshes stay outside `stainMeshes` and `hitProxy` arrays so pointer raycasting passes cleanly without blocking touches.

3. **Integration (`Room3DView.ts`, `PersonalRoomScene.ts`):**
   - Build `HomekeeperRig` in `Room3DView` constructor (placed at a safe open spot computed from `job.furnitureLayout`).
   - On `scrubAt()` or `snapClutterItem()`: command Homekeeper to stand safely beside the action spot (`computeSafeStandPoint`) and play `scrub` animation.
   - On `setToolMode(mode)`: immediately swap handheld `Lap` vs `Pel` mesh and trigger `markDirty()`.
   - On `emitProgressAndCheckWin()` reaching 100%: switch Homekeeper to `celebrate` pose BEFORE `captureThumbnailDataUrl()` so the **After** snapshot captures the cheering Homekeeper in the spotless room!
   - In `PersonalRoomScene` (`readonlyMode: true`): allow tapping floor (`onFloorTap`) to walk the Homekeeper around your personal Kos room!
   - Dispose all Homekeeper geometries/materials cleanly inside `Room3DView.destroy()`.
