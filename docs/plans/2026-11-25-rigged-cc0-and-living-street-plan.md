# Rigged CC0 Characters + Living Neighborhood Street (*Jalan Komplek 3D*) Plan

**Goal:** Elevate ART Simulator toward million-player cozy mobile quality (*Warung Life Simulator* / *Animal Crossing* feel) by replacing primitive character geometry with real **CC0 Kenney Mini Characters (`SkinnedMesh` + `THREE.AnimationMixer`)**, adding **avatar selection** and **1.5× tool-match juice**, and introducing a **3D Neighborhood Street (`Jalan Komplek`)** where your character walks and talks with strolling NPC neighbors for daily banter, small cash tips, and contract launches.

## 1. CC0 Assets & Bundle Budget (`public/models/characters/`)
- Source: **Kenney Mini Characters v2.0 (CC0 1.0)** — already verified from `kenney.nl/assets/mini-characters`.
- Files to copy (~1.25 MB total, fits well under `vite.config.ts` 4 MB PWA precache):
  - `public/models/characters/Textures/colormap.png` (11 KB — isolated in `characters/Textures/` so no URI collision with furniture kit)
  - `character-female-a.glb` (Sari), `character-female-b.glb` (Maya), `character-male-a.glb` (Budi), `character-worker.glb` (Pak Eko), `character-female-c.glb` (Rina / NPC)
- Embedded animations verified in GLB: `idle`, `walk`, `interact-right`, `pick-up`, `jump`, `emote-yes`.
- Native GLB mesh height: `0.776m` → render at **`scale = 1.28`** (`~0.99m` tall) so characters match Kenney Furniture Kit (`desk.glb = 0.60m`, `bedSingle.glb = 0.45m`).

## 2. Pure Core Modules (Strict TDD)
1. **`src/core/avatars.ts`:**
   - `AVATARS`: `sari`, `maya`, `budi`, `eko` with bilingual names & `.glb` filenames; `isValidAvatarId()`, `getAvatarSpec()`.
2. **`src/core/neighborhood.ts`:**
   - `NEIGHBORS`: 5 resident NPCs (`rina`, `ibu_sari`, `pak_budi`, `bang_deni`, `lord_arthur`) each with `modelName`, sidewalk lane `z`, speed, bilingual greeting lines, `tipRp` (`3000..7500`), and linked `jobId` (`kos-rina` .. `kastil-lord-arthur`).
   - `claimNpcChatReward(state, npcId, dateKey)`: awards `tipRp` + `10 XP` **at most once per NPC per `dateKey`** (anti-farm guard persisted in `state.npcChattedDates[npcId] = dateKey`).
   - `createNpcPatrols()` & `stepNpcPatrol(npc, dtSec)`: pure deterministic sidewalk patrol (`x in [-2.4, 2.4]`, reverse at edges, pause timer when `talking`).
3. **`src/core/save.ts` & `src/core/types.ts`:**
   - Extend `GameState` with `avatarId: AvatarId` (default `'sari'`) and `npcChattedDates: Record<string, string>` (default `{}`). Validate/sanitize both in `migrateSave()` cleanly without breaking v1/v2 saves.

## 3. Rigged 3D Character Controller (`src/game/homekeeper3d.ts`)
- Load `/models/characters/${modelName}` via `GLTFLoader` and instantiate using **`SkeletonUtils.clone(gltf.scene)`** (`three/examples/jsm/utils/SkeletonUtils.js`) so `SkinnedMesh` bone bindings stay intact when multiple characters (or player + NPCs) are in the same scene!
- Attach `Lap` / `Pel` tool meshes to the `'arm-right'` bone (`scene.getObjectByName('arm-right')`) with tested local offset so the rag/mop moves with skeletal animations.
- Wrap `THREE.AnimationMixer` with `idle`, `walk`, `interact-right` (`scrub`), `jump` (`celebrate`), `emote-yes` (`talk`), and smooth `crossFadeTo(..., 0.15)`.
- Maintain on-demand battery conservation:
  - In `Room3DView` / `Street3DView`, `tick(nowMs)` clamps `dtSec = Math.min(0.05, ...)`.
  - When `pose === 'idle'` in `Room3DView`, stop demanding WebGL renders once cross-fade settles (`needsFrame = false`), OR in `Street3DView` drive active patrol/walk at smooth ~30–60fps while `StreetScene` is open and clean up everything on `shutdown`.
  - Keep `castShadow = false` on all character meshes + share `contactShadowTex` disc underneath so `shadowMap` never rebuilds per frame.

## 4. Living Neighborhood Street (`src/game/StreetScene.ts` & `Street3DView.ts`)
- Accessible from a **"Jalan"** / **"Street"** pill button right in `MenuScene` header/action bar (keeping all 4 existing tabs intact!).
- 3D environment: cozy Indonesian sidewalk & asphalt lane, dashed center lines, procedural grass/curb, warm streetlamps, potted plants, and `kos`/`warung` facade silhouettes built from existing Kenney `.glb` props + procedural textures (`roomMaterials.ts`).
- Player avatar stands on the sidewalk; tapping sidewalk walks player there (`onFloorTap`); 3 strolling NPCs patrol the sidewalk with floating Phaser name badges projected via `projectWorldToCanvas`.
- Tapping an NPC (invisible `SphereGeometry(0.45)` hit proxy): pauses NPC patrol, faces player & NPC toward each other, plays `emote-yes` wave, opens cozy **Dialogue Modal** (neighbor line + daily `"Sapa (+Rp X)"` reward button if not chatted today + `"Buka Kontrak"` shortcut if unlocked!).

## 5. Million-Player Polish in `RoomScene.ts` & `MenuScene.ts`
- **Tool-Match Feedback (`RoomScene.ts`):** When scrubbing with the `1.5×` matching tool (`Lap` on dust/crayon, `Pel` on spill/mud/grease), update toast with `✨ 1.5× Cocok!`; if scrubbing with the wrong tool for > 1.2s, gently suggest the matching tool (`💡 Coba Pel!` / `💡 Coba Lap!`).
- **Avatar Picker (`MenuScene.ts` → `Kamar Ku` tab):** 4 compact avatar pills (`Sari`, `Maya`, `Budi`, `Pak Eko`) letting players customize who cleans rooms and walks the neighborhood street.
