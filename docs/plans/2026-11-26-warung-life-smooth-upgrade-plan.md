# Warung Life Smooth Visual & Character Upgrade Plan (2026-11-26)

## Goal
Eliminate the "squarish / toy-block" look in ART Simulator and align directly with our **Warung Life Simulator** North Star by upgrading:
1. **Smooth Human-Proportion CC0 Characters (`Quaternius Animated Characters` + `Pug`):** Replace boxy `Kenney Mini Characters` (`0.776m` chibis) with smooth `1:5.5` human-proportion CC0 models (`casual-female.glb`, `casual-2-female.glb`, `casual-3-female.glb`, `casual-male.glb`, `casual-2-male.glb`) and `farm-animals/pug.glb` (`Bruno`) from `XXIautomate/realm-cc0-library`.
2. **Smooth Architectural & Nature Street (`city-kit-suburban` + `stylized-nature` + `car-kit`):** Replace raw `BoxGeometry`/`ConeGeometry` street houses & sphere-on-stick trees in `Street3DView.ts` with detailed CC0 GLBs (`building-type-a/b/c/f.glb`, `fence-1x3.glb`, `planter.glb`, `common-tree-1/2.glb`, `bush-common-flowers.glb`, `bush-common.glb`, `sedan.glb`, `van.glb`) plus soft AO crevice strips and `THREE.Fog`.
3. **Warm Smooth Lighting, Tone Mapping & Beveled Geometry:** Enable `THREE.ACESFilmicToneMapping` (`exposure = 1.06`) in both `Room3DView` and `Street3DView`, replace sharp 90° room walls/floor/curbs with `RoundedBoxGeometry` (beveled edges), and enrich warm interior/exterior color harmony.
4. **2D Illustrated Dialogue Bust Portraits (`src/game/portraits.ts`):** Render crisp smooth Canvas2D character/pet bust portraits inside `StreetScene.ts`'s bottom Story Dialogue Bar (matching *Warung Life*'s NPC phone/story dialogue bar).

## North Star Alignment (ART House In-and-Out Setting)
- **Indoor Rooms (`Room3DView` / `PersonalRoomScene`):** Stay 100% authentic **ART (Asisten Rumah Tangga)** house interiors — bedrooms, kitchens, living rooms, villa terraces, and the homekeeper's personal Kos room.
- **Outdoor Residential Street (`Street3DView`):** Houses, yards, porches, fences, lush trees, parked family cars, and sidewalks **outside the homeowners' houses** where homeowner kids (`Adik Bima`), husband/wife (`Ibu Sari`, `Pak Budi`), and house pets (`Mochi`, `Bruno`) stroll — **never** a *warung* shop stall.

## Adversarial Review Fixes Integrated
1. **Dialogue Portrait vs `greetBtn` Clearance (`StreetScene.ts`):** Place the `68×68` rounded portrait at `(58, 612)` (`y = 578..646`), strictly above `greetBtn` (`x = 154, y = 672, h = 34` → `y = 655..689`), and align `nameTxt`/`msgTxt` to `x = 104` (`wordWrap: { width: 318 }`).
2. **No UV Pinching on Textured Walls/Floor (`Room3DView.ts`):** Keep `BoxGeometry` on UV-mapped floor & walls; use `RoundedBoxGeometry` (`radius = 0.035, segments = 3`) exclusively on **untextured solid-color trims** (`baseBack`, `baseLeft`, kanstin curbs, bench seats).
3. **Shared Scenery Cache Safety (`Street3DView.ts`):** Tag every cloned mesh & material from `loadMeshoptGltf` (`city-kit-suburban`, `stylized-nature`, `car-kit`) with `userData.sharedAsset = true` so `destroy()` never disposes cached GPU buffers/textures.
4. **Bone Scale/Orientation Calibration & `readyPromise` (`homekeeper3d.ts`, `Room3DView.ts`, `Street3DView.ts`):** Measure `Fist.R` accumulated scale on Quaternius `CharacterArmature` (which uses `0.01` Blender->Three armature scale inside GLB!) and counter-scale/orient `Lap`/`Pel` accurately; expose `readyPromise` on `Room3DView` & `Street3DView`.
5. **Slim PWA Precache:** `MeshoptDecoder` embeds inline WASM with no extra `.wasm` files needed in `vite.config.ts`; remove replaced `character-*.glb` and `characters/Textures/` after new models pass tests.

## Verified Asset Inventory & Scales (Pre-Probed with Three.js + MeshoptDecoder)
All new `.glb` files come from `XXIautomate/realm-cc0-library` (**CC0 1.0**, self-contained with embedded WebP textures & `EXT_meshopt_compression`):
- **Characters (`/public/models/characters/`):**
  - `casual-female.glb` (`Sari`, `Ibu Sari`) — unscaled height `1.795m` → `scale3D = 0.56` (`1.00m` adult)
  - `casual-2-female.glb` (`Maya`) — `scale3D = 0.56`
  - `casual-3-female.glb` (`Tante Rina / extra`) — `scale3D = 0.56`
  - `casual-male.glb` (`Budi`, `Adik Bima` at `0.42` kid scale = `0.75m`)
  - `casual-2-male.glb` (`Pak Eko`, `Pak Budi`) — `scale3D = 0.56`
  - **Exact Skeleton Bones:** `Fist.R`, `LowerArm.R`, `Head`, `CharacterArmature`
  - **Exact Animation Clips:** `CharacterArmature|CharacterArmature|Idle`, `...|Walk`, `...|Walk_Carry`, `...|PickUp`, `...|Punch`, `...|Victory`, `...|SitDown`, `...|Defeat`
- **Pets (`/public/models/pets/`):**
  - `pug.glb` (`Bruno`) — unscaled height `2.659m`, length `3.509m` → `scale3D = 0.16` (`0.42m` tall), clips: `Armature|Armature|Idle`, `Armature|Armature|Jump`
  - `animal-cat.glb` (`Mochi`) — existing CC0 `0.34` scale
- **Street Scenery (`/public/models/street/`):**
  - `building-type-a.glb` (`25 KB`), `building-type-b.glb` (`34 KB`), `building-type-c.glb` (`25 KB`), `building-type-f.glb` (`33 KB`) — unscaled `~7.15m × 4.58m × 5.65m` → `scale = 0.36` (`~2.57m` wide)
  - `fence-1x3.glb` (`9 KB`), `planter.glb` (`9 KB`)
  - `common-tree-1.glb` (`316 KB`), `common-tree-2.glb` (`295 KB`), `bush-common.glb` (`65 KB`), `bush-common-flowers.glb` (`182 KB`) — unscaled tree `~7.26m` → `scale = 0.28` (`~2.03m` tall)
  - `sedan.glb` (`32 KB`), `van.glb` (`33 KB`) — unscaled `~4.49m` long → `scale = 0.45` (`~2.02m` long)

## File-by-File Changes
1. **Asset Download & Cleanup:**
   - Download the verified CC0 `.glb` files into `public/models/characters/`, `public/models/pets/pug.glb`, and `public/models/street/`.
   - Remove unused `character-female-a/b/c.glb`, `character-male-a.glb`, `character-worker.glb`, and `characters/Textures/` (only after updating `avatars.ts` & `neighborhood.ts` & tests so PWA precache stays fast & slim).
2. **`src/core/avatars.ts` & `src/core/neighborhood.ts`:**
   - Update `AVATARS` (`casual-female.glb`, `casual-2-female.glb`, `casual-male.glb`, `casual-2-male.glb`) and add `scale3D: number` (`0.56`).
   - Update `NEIGHBORS` (`casual-male.glb` @ `0.42` for `adik_bima`, `casual-3-female.glb` @ `0.56` for `ibu_sari`, `casual-2-male.glb` @ `0.56` for `pak_budi`, `pug.glb` @ `0.16` for `bruno_dog`, `animal-cat.glb` @ `0.34` for `mochi_cat`) + add `portraitPalette` metadata for 2D portraits.
3. **`src/game/homekeeper3d.ts`:**
   - Register `MeshoptDecoder` (`await MeshoptDecoder.ready`) on a shared `GLTFLoader` helper exported for `Street3DView` too (`loadMeshoptGltf`).
   - Support dynamic `scale3D` (`createHomekeeperRig(modelPath, contactShadowTex, scale3D = 0.56)`), attach handheld `Lap`/`Pel` to `Fist.R` (fallback `LowerArm.R` / `arm-right`), and match animation clips case-insensitively by suffix/substring (`Idle`, `Walk`, `Punch`, `Victory`, `Jump`) so both `CharacterArmature|CharacterArmature|Idle` and `idle` work seamlessly.
   - Apply smooth roughness polish (`roughness >= 0.72` clamping on overly glossy PBR defaults if needed, never mutating shared materials without tagging `userData.sharedAsset = true`).
4. **`src/game/Room3DView.ts`:**
   - Enable `THREE.ACESFilmicToneMapping` (`toneMappingExposure = 1.06`) on renderer.
   - Replace sharp `BoxGeometry` floor slab, left/back walls, and skirting trim with `RoundedBoxGeometry` (`radius = 0.04`, `segments = 3`) so room edges catch soft warm highlights instead of razor corners.
   - Pass `avatarSpec.scale3D` to `createHomekeeperRig`, and map `'scrub'`/`'celebrate'`/`'walk'` poses cleanly to Quaternius clips (`Punch`/`PickUp`, `Victory`, `Walk`, `Idle`).
5. **`src/game/Street3DView.ts`:**
   - Enable `THREE.ACESFilmicToneMapping` (`toneMappingExposure = 1.06`) + `THREE.Fog(0xd7ebdd, 11, 24)`.
   - Replace raw primitive houses/trees with static CC0 `building-type-{a,b,c,f}.glb`, `fence-1x3.glb`, `planter.glb`, `common-tree-{1,2}.glb`, `bush-common(-flowers).glb`, `sedan.glb`, `van.glb` loaded via shared `loadMeshoptGltf` + `RoundedBoxGeometry` kanstin curb blocks + soft foundation AO strips (`contactShadowTex`).
   - Keep `castShadow = true` strictly on static scenery (`shadowMap.autoUpdate = false`, `needsUpdate = true` once scenery loads), and `castShadow = false` on player/NPCs.
   - Ensure `destroy()` disposes all non-shared geometries/materials and guards against unmount during async GLB loads (`if (this.destroyed) return`).
6. **`src/game/portraits.ts` & `src/game/StreetScene.ts`:**
   - Pure Canvas2D portrait generator (`drawNeighborPortrait(canvas, spec)`) creating smooth rounded 2D bust portraits (`72×72` rounded badge) in Phaser textures (`portrait_<id>`), properly cleaned up on scene shutdown (`textures.remove`).
   - Display the portrait inside `StreetScene.ts`'s bottom Story Dialogue Bar (`y = 636, h = 126`) on the left (`x = 64`), shifting dialogue name/text cleanly to `x = 114` (`wordWrap: { width: 306 }`) above the action buttons.

## TDD Test Plan (RED → GREEN)
1. `tests/core/avatars.test.ts`: Assert every `AvatarSpec` has valid `scale3D` (`> 0.4 && <= 0.7`) and `.glb` filename exists under `public/models/characters/` on disk!
2. `tests/core/neighborhood.test.ts`: Assert every `NeighborSpec` has valid `modelPath` existing on disk under `public/models/`, valid `portrait` colors, and `scale3D` scaled appropriately (`kid < spouse`, `pet < 0.4`).
3. `tests/core/animationMatch.test.ts` (new pure helper `resolveClipName(availableNames, preferredTokens)` in `src/core/character.ts` or `src/core/animationMatch.ts`): Assert `CharacterArmature|CharacterArmature|Idle`, `Armature|Armature|Jump`, and `idle` all match deterministically without Three.js dependency.
4. `tests/core/streetAssets.test.ts`: Assert every street scenery GLB referenced in `Street3DView` (`STREET_SCENERY_FILES` constant) exists on disk under `public/models/street/` and stays under PWA `4 MB` limit.
5. `npm test && npm run build` (`tsc --noEmit && vite build`), **Adversarial Pre-Commit Review**, Coolify deploy to `https://game.shr.co.id`, and live `browser_exec` + `vision_analyze` inspection across Menu, Street, Story Dialogue Portrait, and Room!
