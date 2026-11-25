# ART Simulator ("Cozy Homekeeper") — Design Spec & TDD Implementation Plan

**Goal:** Build and deploy a tactile, portrait-first mobile & desktop 2D room-tidying and restoration simulator (**ID:** *ART Simulator*, **EN:** *Cozy Homekeeper*) playable instantly via HTTPS at `https://game.shr.co.id` (PWA-installable on mobile, mouse-playable on desktop).

**Architecture:** Clean separation between a deterministic, pure-TypeScript simulation core (`src/core/`: economy, jobs/levels, upgrades, i18n, versioned save state — 100% Vitest-tested) and a Phaser 3 + Vite presentation/audio layer (`src/game/`: responsive portrait canvas, `RenderTexture` tactile scrub/wipe masking, drag-and-snap clutter organizing, procedural Web Audio ASMR synthesizer, and clean UI scenes).

**Tech Stack:** TypeScript 5, Vite 6, Phaser 3 (`phaser`), Vitest, `vite-plugin-pwa`, Docker (`nginx` static production image) deployed on Coolify + Cloudflare Tunnel (`https://game.shr.co.id`).

---

## Global Constraints
- **Zero external assets / zero AI art slop:** All room visuals, tools, furniture, stains, and clutter sprites are crisp procedural vector/canvas textures generated consistently in code; all ASMR audio (scrubbing, pops, chimes) is procedurally synthesized via Web Audio API (`ctx.resume()` synchronously on `pointerdown`) with mute toggle.
- **No mixed languages on the same surface & canonical currency:** Full `id` (default) and `en` language packs (`src/core/i18n.ts`). Store all balances, wages, and upgrade costs in canonical `Rp` integers (`25000`); `formatMoney(25000, 'id') === 'Rp 25.000'` and `formatMoney(25000, 'en') === '$25'` (display conversion only so mid-save language switch never corrupts affordability). Free items display `Gratis` / `Free` (never `Rp 0` / `$0`).
- **Mobile-first + Desktop-friendly:** Logical portrait canvas `450x800` scaled with `Phaser.Scale.FIT` + `CENTER_BOTH`, `touch-action: none; overscroll-behavior: none;` on `html, body, canvas`, large touch targets (`>= 48px`), `activePointerId` locking, and drag/scrub reset on `pointerup`, `pointerupoutside`, and `blur`.
- **Strict TDD & Adversarial Review:** Every simulation module (including `CoverageGrid` & state invariants) gets failing Vitest tests before implementation; plan and diff undergo adversarial subagent review before commit/deploy.

---

## File Structure

| File | Responsibility |
|---|---|
| `package.json`, `tsconfig.json`, `vite.config.ts`, `index.html` | Build, Vitest, strict TS, PWA manifest (`registerType: 'autoUpdate'`, `skipWaiting: true`, `clientsClaim: true`), mobile CSS `touch-action: none; overscroll-behavior: none` |
| `src/core/types.ts` | Shared types (`Locale`, `GameState`, `JobSpec`, `StainSpot`, `ClutterItem`, `UpgradeId`, `JobResult`, `SaveFile`) |
| `src/core/i18n.ts` | `id` & `en` dictionaries, `t(locale, key)`, `formatMoney(amountRp, locale)` |
| `src/core/coverage.ts` | Deterministic `CoverageGrid` (`12x12` cell grid in stain local coordinates, line-segment interpolation between `prev` & `curr`, `>= 85%` auto-complete threshold) shared with `RenderTexture.erase()` |
| `src/core/jobs.ts` | 5 progressive room specs (`kos-rina`, `ruang-tamu-budi`, `dapur-sari`, `villa-senja`, `kastil-lord-arthur`), story notes, non-overlapping stain & clutter coordinates (`450x800`) |
| `src/core/economy.ts` | Pure deterministic economy in canonical `Rp` (`UPGRADES`, `calculateJobPayout`, `purchaseUpgrade`, `applyJobResult`, `getToolStats`) |
| `src/core/save.ts` | Versioned `StorageAdapter` save/load (`SAVE_VERSION = 1`), strict validation, corrupt-data recovery, `migrateSave`, `resetSave` |
| `src/audio/asmrSynth.ts` | Safe Web Audio API ASMR synth (synchronous `ctx.resume()` on `pointerdown`, scrub noise, sparkle pop, snap chime, cash bell, mute support) |
| `src/game/textures.ts` | Cohesive cozy vector/canvas texture generator for rooms, stains, tools, clutter items, UI buttons |
| `src/game/RoomScene.ts` | Phaser 3 tactile gameplay scene: `CoverageGrid` synced 1:1 with `RenderTexture.erase()` in stain local space, drag-and-snap clutter placement (`activePointerId` lock, scrub disabled while dragging), progress calculation, story/cashbook modal |
| `src/game/MenuScene.ts` | Title / House Map / Tool Upgrade Shop / Cashbook scene with `ID`/`EN` toggle & Mute toggle |
| `src/main.ts` | Boot Phaser game + register PWA service worker |
| `tests/core/*.test.ts` | Vitest TDD suites for `i18n`, `coverage`, `jobs`, `economy`, `save` (incl. `migrateSave` & mid-save locale switch), `audio`, and full 5-day economy playability invariant |
| `Dockerfile`, `nginx.conf` | Multi-stage build (`node:22-alpine` → `nginx:alpine`) on port `80`, `Cache-Control: no-cache, no-store, must-revalidate` for `index.html` & `sw.js`, no HTTPS redirect (CF Tunnel terminates SSL) |

---

## Bite-Sized Tasks

### Task 1: Project Scaffold & `src/core/types.ts` + `src/core/i18n.ts`
- Initialize project in `/home/ubuntu/projects/art-simulator` (`phaser`, `vite`, `vitest`, `typescript`, `vite-plugin-pwa`).
- Write failing tests (`tests/core/i18n.test.ts`): verifies parity of all translation keys across `id` & `en`, `formatMoney(0, 'id') === 'Gratis'`, `formatMoney(0, 'en') === 'Free'`, `formatMoney(25000, 'id')` formats `Rp 25.000`, `formatMoney(25000, 'en') === '$25'`.
- Implement `src/core/types.ts` and `src/core/i18n.ts` cleanly.

### Task 2: Deterministic Scrub Coverage (`src/core/coverage.ts`) & Progressive House Catalog (`src/core/jobs.ts`)
- Write failing tests (`tests/core/coverage.test.ts`): verifies local `(0..w, 0..h)` grid initialization, fast-swipe line interpolation marks intermediate cells without gaps, brush radius scaling, out-of-bounds safety, and `>= 85%` `isComplete` threshold.
- Write failing tests (`tests/core/jobs.test.ts`): verifies all 5 houses have bounds inside `450x800` playfield (`y: 110..650`), non-overlapping bounding boxes across all stains, clutter starts, and clutter target zones, unique IDs, `>= 2` stains + `>= 3` clutter items per house, both `id` and `en` story/title strings.
- Implement `src/core/coverage.ts` and `src/core/jobs.ts`.

### Task 3: Economy, Upgrades & Headless Playthrough Invariant (`src/core/economy.ts`)
- Write failing tests (`tests/core/economy.test.ts`):
  - Base wage + speed star bonus (3 stars `<= parTimeSec`, 2 stars `<= parTimeSec * 1.5`, 1 star otherwise) + upgrade tip multiplier in canonical `Rp` integers.
  - `purchaseUpgrade` fails cleanly if insufficient funds or already owned, never drops balance `< 0`.
  - Mid-save locale switch (`id` -> `en` -> `id`) preserves exact canonical `balance` and upgrade affordability.
  - Full 5-day simulation invariant: playing all 5 jobs sequentially generates positive progression enough to afford core upgrades without softlocks.
- Implement `src/core/economy.ts`.

### Task 4: Versioned Save Persistence (`src/core/save.ts`)
- Write failing tests (`tests/core/save.test.ts`): save/load roundtrip via injected storage mock, corrupt JSON recovery, `migrateSave()` upgrading legacy v0/partial payload to v1 safely, unknown/invalid field sanitization, `resetSave()`.
- Implement `src/core/save.ts`.

### Task 5: Procedural ASMR Synth (`src/audio/asmrSynth.ts`) & Cohesive Textures (`src/game/textures.ts`)
- Implement `AsmrSynth` with synchronous `ctx.resume()` unlock on `pointerdown` and safe headless fallback + unit test (`tests/core/audio.test.ts`).
- Implement `textures.ts` with consistent cozy pastel/warm palette (`#FDF6EC`, `#E07A5F`, `#3D405B`, `#81B29A`, `#F2CC8F`).

### Task 6: Phaser Scenes (`MenuScene.ts`, `RoomScene.ts`, `main.ts`) + Build Verification
- `MenuScene`: Title screen (*ART Simulator* / *Cozy Homekeeper*), House selector cards (locked/unlocked + star badges), Tool Upgrade Shop (`Toko Alat` / `Tool Shop`), Cashbook (`Buku Kas`), Language toggle (`ID`/`EN`), Audio mute toggle.
- `RoomScene`:
  - Top HUD (`title`, progress `%`, live timer, back button, mute).
  - Tactile grime spots (`RenderTexture` + `CoverageGrid` using identical stain local `(x, y, prevX, prevY, radius)` coordinates; auto-completes and fades out at `>= 85%`).
  - Clutter drag-and-drop with dotted target outline highlight + snap animation + story bubble pop (`activePointerId` locking; scrubbing disabled while `draggedItem !== null`; drag/scrub state cleanly reset on `pointerup`, `pointerupoutside`, and `blur`).
  - Completion overlay: Homeowner's secret story note + 1–3 stars + itemized payout + "Next House / Back to Map".
- Verify `npx vitest run`, `npx tsc --noEmit`, `npm run build`.

### Task 7: Dockerize, Push GitHub Repo (`vrijmetse/art-simulator`), Deploy to `https://game.shr.co.id`, & Live Browser QA
- Check `df -h` on VPS before Docker build.
- Multi-stage `Dockerfile` + `nginx.conf` (port `80`, gzip, `no-cache, no-store, must-revalidate` for `index.html` & `sw.js`, no HTTP→HTTPS redirect behind CF Tunnel).
- Create `vrijmetse/art-simulator` on GitHub (`main` branch).
- Create Coolify app (`http://game.shr.co.id`) + Cloudflare DNS (`game.shr.co.id`) + GET+merge CF Tunnel ingress rule cleanly.
- Verify live `https://game.shr.co.id/` on desktop & mobile viewport (`390x844`!) in `browser_exec`: canvas loads, `ID`/`EN` toggle, enter House 1, pointer scrub & clutter drag, zero console/runtime errors!
