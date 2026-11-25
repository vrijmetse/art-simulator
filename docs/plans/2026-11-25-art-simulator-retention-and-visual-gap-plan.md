# ART Simulator — Visual Polish & Long-Term Retention Gap Closure Plan

**Date:** 2026-11-25  
**Target Repo:** `/home/ubuntu/projects/art-simulator` (`https://game.shr.co.id`)  
**Benchmark Sources Audited:**
- Open-source Three.js/PWA cozy sims: `juw12/bilas` (MIT) & `juw12/teduh` (MIT)
- Public commercial mechanics & player reviews: *Warung Life Simulator* (`com.neopawstudio.warunglife`), *PowerWash Simulator*, *Unpacking*, *House Flipper*, *A Little to the Left*

---

## 1. Visual, UX & Gameplay Gap Audit (Verified Against Screenshots & Source)

| Dimension | Benchmark (`bilas`, `teduh`, *Warung Life*, *PowerWash*) | Current `art-simulator` (`884d6c1`) | Plan Target |
|---|---|---|---|
| **Surface Detail & Contact Shadows** | `bilas`: `19k–45k` unique colors, ceramic tile glaze variance, wood grain, soft radial `contactShadow` under props, clock/posters/sky window | `4.4k` unique colors, flat walls, basic grid floor, no contact shadows | Procedural wood-grain & tile/wainscoting textures, soft radial contact shadow planes under every furniture/prop, framed sky window & wall art |
| **HUD Footprint** | Floating compact pill HUDs leaving 84%+ viewport to the 3D scene | Heavy `#3D405B` top (`96px`) + bottom (`124px`) bars consuming 27.5% of screen | Compact sleek floating HUD pills/strips (`top 72px`, `bottom 94px`) opening ~79% of viewport to 3D |
| **Interaction Ergonomics** | Tap-or-drag fallback (`bilas`), `depthTest: false` pulsing target rings, active tool/sponge feedback | Drag-only clutter (missed drags reset without clear guidance), rings clip on rugs | Tap-to-select + tap-target fallback alongside drag, `depthTest: false, renderOrder: 10` rings, 3D sponge/bubble burst particles on scrub/snap |
| **Retention Loop (Playtime)** | 7–30+ days via Daily Contracts (*A Little to the Left*), Personal Base (*House Flipper*), Career Ranks, Before/After timelapse, 30-day Calendar (*Warung Life*) | 5 linear levels (~8–12 min total playtime), 5 flat upgrades, no daily loop | **Daily Shift (*Tugas Harian*)** with streak, **Kamar Kos Pribadi** decoration sink, **Career Ranks**, **Before/After card**, **Kalender Hadiah**, **Tool Modes** (Sponge / Mop / Duster) |
| **Monetization Readiness** | *Warung Life*: Rp 29.000 one-time No-Ads pass + tip packs + optional rewarded ad | None | Keep web/PWA 100% ad-free & clean; structure pure-TS `entitlements` / `adFree` state flag ready for future Capacitor + Play Billing Rp 29k pass without cluttering current UX |

---

## 2. Phase A — Visual Diorama Polish & Tactile 3D Feel

### A1. Pure Procedural Room Textures & Contact Shadows (`src/game/roomMaterials.ts` + `Room3DView.ts`)
- **Wood & Tile Canvas Textures (`256x256`):**
  - Replace plain floor lines with multi-plank warm wood grain (alternating plank tones + subtle knots/seams) for living/bed/castle rooms, and subtle ceramic checker/tile glaze sheen for kitchen/villa!
  - Add subtle vertical wainscoting/wallpaper striping + dado rail on back/left walls, plus a **sky gradient window** (day/warm sunset per room palette) and a **framed wall poster / wall clock** prop so walls feel alive.
- **Contact Shadows:**
  - Generate one shared `64x64` radial gradient `CanvasTexture` (`rgba(35,30,25,0.45) -> transparent`) and place flat `depthWrite: false` shadow quads (`y = 0.004`) beneath every `furnitureLayout` prop (`width/depth` derived from `Box3` of the normalized GLB!).
- **Target Ring Visibility:**
  - Update `targetRing` material to `depthTest: false, renderOrder: 10` so glowing target markers remain visible even near rugs or table edges.

### A2. 3D Scrub Feedback, Tap-or-Drag Clutter & Sleeker HUD (`Room3DView.ts`, `RoomScene.ts`)
- **3D Scrub Foam / Sparkle Particles:**
  - Lightweight pooled `THREE.Points` or small `InstancedMesh`/sprite pool (`<= 24` particles, zero per-frame allocations) emitting tiny white/cream soap puffs on scrub and gold sparkles on snap/stain clear!
- **Tap-to-Place Accessibility Fallback:**
  - In `Room3DView`: if a player **taps** (pointer down + up within `< 8px` screen movement) an unplaced clutter item, highlight it as `selectedClutter` (gently bobbing + brightening its target ring); tapping the target ring (or within `snapRadiusMeters * 1.4` of `targetPos3D`) snaps it cleanly! Drag-and-drop continues working identically.
- **Tool Mode Selector (Non-Blocking & Cozy):**
  - Categorize stains visually & via optional quick-toggle or automatic highlight: `dust`/`crayon` → **Lap / Kemoceng** (*Sponge/Duster*), `spill`/`mud`/`grease` → **Pel** (*Mop*) — OR keep universal scrubbing by default with **1.5× speed bonus** when matching the recommended tool (`Lap` vs `Pel`) so players never feel blocked/punished, only rewarded!
- **Compact HUD (`RoomScene.ts`):**
  - Trim Top HUD to `72px` height and Bottom HUD to `92px` height with clean floating pill buttons (`←`, `Kerapian %`, Timer, Mute, `↺ Putar`, Tool Toggle / Radar, `Putar ↻`), expanding usable 3D space from `580px` → `636px` height.

### A3. Before / After Snapshot Capture (`Room3DView.ts` + `RoomScene.ts`)
- On level load (after GLBs finish loading & first clean room render), capture a lightweight downscaled `200×356` JPEG/Canvas snapshot of the messy room (`beforeDataUrl`) via `preserveDrawingBuffer: false` synchronous read right after `renderer.render(...)` in `tick()`.
- On 100% completion, capture `afterDataUrl` and render a side-by-side **Sebelum / Sesudah** miniature preview card inside the Completion Modal!

---

## 3. Phase B — Long-Term Retention Loop (7–30+ Days Without Grinding)

### B1. Pure-TS Core Extensions (`src/core/`)
1. **`src/core/types.ts` & `src/core/save.ts`:**
   - Extend `GameState` (version `2`, with automatic lossless migration from `v1` saves!):
     - `xp: number` (earns career XP per job + star bonus)
     - `dailyCompletedDates: string[]` (YYYY-MM-DD local date keys for Daily Shift)
     - `dailyStreak: number`
     - `lastDailyClaimDate: string | null` (Kalender Hadiah / attendance day counter `1..30`)
     - `attendanceDay: number`
     - `ownedDecor: DecorId[]` & `placedDecor: DecorId[]` (Personal *Kamar Kos Pribadi* items!)
     - `album: Record<string, { bestStars: number; completedAt: string }>` (Portfolio milestone badges)
2. **`src/core/career.ts` (New Pure-TS Module):**
   - Career Ranks based on `xp`:
     - `0`: *ART Magang* / *Trainee Keeper*
     - `150`: *ART Terampil* / *Skilled Keeper* (+5% base wage perk)
     - `400`: *ART Andalan* / *Trusted Keeper* (+10% wage + faster scrub)
     - `800`: *Manajer Rumah* / *Estate Steward* (+15% wage)
     - `1400`: *Kepala Tata Graha* / *Grand Steward* (+25% wage)
3. **`src/core/daily.ts` (New Pure-TS Module):**
   - Deterministic seeded PRNG (`mulberry32` seeded by `YYYY-MM-DD`) generating **1 Daily Contract (*Tugas Harian*)** per day from unlocked room templates:
     - Picks a room, spawns **3–4 randomized stain positions/kinds** + **3 shuffled clutter positions** within valid room XZ bounds (using `clampRoomXZ` + furniture collision check so nothing spawns inside furniture!).
     - Awards **+50% Bonus Upah Harian** + increments `dailyStreak` (7-day streak bonus: `+Rp 50.000`).
4. **`src/core/decor.ts` (New Pure-TS Module):**
   - **Kamar Kos Pribadi (Personal Room Sink):** 8–10 purchasable CC0 `.glb` decor items (`pottedPlant.glb`, `lampRoundTable.glb`, `rugRounded.glb`, `bear.glb`, `loungeChair.glb`, `televisionVintage.glb`, `bookcaseOpenLow.glb`, `radio.glb`) ranging from `Rp 30.000` to `Rp 220.000` that physically render inside the player's own interactive 3D **Kamar Sendiri** tab!
5. **`src/core/attendance.ts` (New Pure-TS Module):**
   - **Kalender Hadiah 30 Hari** (inspired by *Warung Life*'s daily reward cadence, balanced for ART economy: `Rp 10.000`–`Rp 15.000` normal days, `Rp 40.000`–`Rp 100.000` milestone days every 5 days, zero coercive lock-in).

### B2. UI Integration (`MenuScene.ts` + `PersonalRoomScene.ts`)
- **`MenuScene.ts`:**
  - Top banner shows **Rank badge**, `Hari N`, `Rp Balance`, `★ Total`, and **Daily Attendance / Streak pill** (`Tugas Harian` button right at top of Map tab!).
  - 4 clean tabs: **`Kontrak`** (5 story houses + Daily Shift card), **`Kamar Ku`** (opens live 3D preview/editor of your personal decorated Kos!), **`Toko`** (Tools + Kos Decor sub-filter), **`Buku Kas`** (History + Career Progress + Portfolio badges).
- **`RoomScene.ts`:**
  - Supports both story `jobId` AND procedural `dailyJob` spec seamlessly!

---

## 4. Strict TDD Matrix (Red → Green → Refactor)

1. `tests/core/save.test.ts`: v1 → v2 lossless save migration, corrupted JSON fallback, decor & daily state persistence.
2. `tests/core/career.test.ts`: XP progression thresholds, rank titles (ID/EN), wage multiplier perks.
3. `tests/core/daily.test.ts`: deterministic same-day `generateDailyJob('2026-11-25')` output, different-day variation, zero furniture-footprint overlap, 100% portrait `projectWorldToCanvas` framing check, streak increment & reset after missed day.
4. `tests/core/decor.test.ts`: purchase & toggle placement of decor in personal room, insufficient funds guard, all decor `.glb` assets exist on disk.
5. `tests/core/attendance.test.ts`: 1 claim per calendar day, 30-day cycle wrap/cap, milestone payouts.
6. `tests/core/math3d.test.ts`: tap-vs-drag threshold helper (`isTapGesture`) + tool-match bonus calculation.

---

## 5. Adversarial Review Resolutions (Integrated Before Implementation)
1. **`save.ts` Migration & Daily IDs:** Keep `SAVE_KEY = 'art_sim_save_v1'` with `SAVE_VERSION = 2` so existing player saves migrate losslessly; allow `jobId.startsWith('daily-')` in `cashbook` validation.
2. **`Before/After` Snapshot Timing & Async Phaser Texture:** Capture `beforeDataUrl` inside `tick()` **only** after `assetsLoaded && renderer.render()` finishes, drawing `this.threeCanvas` onto a `200×356` offscreen 2D canvas (`toDataURL('image/jpeg', 0.75)`). Load in `RoomScene` via `HTMLImageElement` + `onload` → `this.textures.addImage(key, img)` (cleaning up old keys first).
3. **Particle Disposal & Idle Guard:** `Room3DView.destroy()` disposes both `THREE.Mesh` and `THREE.Points`; `tick()` keeps `this.dirty = true` only while `activeParticleCount > 0`.
4. **Static Furniture Footprints in `daily.ts`:** Define `FURNITURE_FOOTPRINTS: Record<string, [number, number]>` from real GLB dimensions so pure-TS `generateDailyJob` guarantees zero overlap.
5. **Same-Day Daily Replay Guard:** `applyJobResult` checks `dailyCompletedDates.includes(dateKey)` so replaying today's Daily Shift never double-awards the +50% daily bonus or increments streak twice.
6. **Tap-vs-Scrub & `PersonalRoomScene` Isolation:** Track `pointerDownPos`; tap (`< 8px` move) prioritizes snapping `selectedClutter` when active instead of scrubbing underneath. `Kamar Ku` launches a dedicated `PersonalRoomScene` (just like `RoomScene`) so `MenuScene` remains opaque and only 1 WebGL context ever exists.
7. **4-Tab Sizing & Tool Mode:** Use `100px` pills (`11px` bold) in `MenuScene`, and keep universal scrubbing with a `1.5×` speed bonus on matching `Lap`/`Pel` mode.

## 6. Verification Criteria (Before Declaring Done)
1. **Stage 2 Adversarial Plan Review** passes with 0 unresolved CRITICAL/IMPORTANT items.
2. **All Vitest suites + `tsc --noEmit` + `vite build`** pass cleanly (no `| tail` masking).
3. **Stage 4 Adversarial Pre-Commit Review** passes before push.
4. **Live End-to-End Browser QA (`https://game.shr.co.id`)**:
   - Inspect live screenshots showing improved 3D textures, contact shadows, sleeker HUD, Daily Shift launch, Personal Kos 3D view, and Before/After completion modal.
   - Verify mobile portrait (`390×844`) & desktop (`1280×800`) zero JS errors and 100% playable completion.
