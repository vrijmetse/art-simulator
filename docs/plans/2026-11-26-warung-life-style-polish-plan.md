# Warung-Life-Style Indonesian Visual & UX Polish Plan

**Goal:** Align ART Simulator's visual style, camera perspective, lighting, NPC street framing, and HUD warmth directly with *Warung Life Simulator*'s proven Indonesian cozy aesthetic (high-angle 3/4 sunlit kampung street, lush props, black-and-white *kanstin* curb, `!` neighbor pins, bottom story dialogue bar, clean wallet formatting, and cohesive room lighting/facing).

## 1. Pure Core Fixes (Strict TDD)
1. **Wallet vs Price Formatting (`src/core/i18n.ts`):**
   - Keep `formatMoney(0, loc)` returning `'Gratis'` / `'Free'` for prices/rewards.
   - Add `formatBalance(amountRp, loc)` always returning `'Rp 0'` / `'$0'` when wallet balance is 0 so `"Hari 1 • Gratis • ★ 0/15"` never appears in wallet headers.
2. **Spaced NPC Street Patrols (`src/core/neighborhood.ts`):**
   - Spread the 5 NPC `startX` values (`-3.2, -1.6, 0.2, 1.8, 3.2`) and `laneZ` (`0.45..1.55`) across `x in [-3.8, 3.8]` so NPCs never clump on screen load.
3. **Visible Floor Prop Scaling (`src/core/jobs.ts`):**
   - Bump `rina-laptop` `scale3D` from `0.72` -> `0.95` (preserving `readGlbBounds` anti-clipping tests).

## 2. High-Angle 3/4 Sunlit Kampung Street (`src/game/Street3DView.ts` & `src/game/StreetScene.ts`)
- **Camera:** Diagonal 3/4 high-angle perspective (`camera.position.set(4.8, 5.4, 6.2)` looking at `(0, 0.4, 0.5)`) mirroring *Warung Life Simulator*'s *Jalan-jalan Keliling Kampung* framing.
- **Golden Afternoon Lighting + Cast Shadows:** Enable `PCFShadowMap` (`1024x1024`, `autoUpdate = false`, updated on asset load) with directional golden sunlight casting crisp shadows from houses, fences, trees, and lampposts onto the paving sidewalk.
- **Indonesian Kampung Architecture & Props:**
  - Procedural terracotta roof-tile (*genteng*) texture & warm plaster walls (`src/game/roomMaterials.ts`).
  - Porch canopies, wooden fences/gates, *Pos Ronda* shelter, alternating black-and-white *kanstin* curb blocks along the asphalt road, and Kenney `pottedPlant.glb` / `plantSmall1.glb` / `plantSmall2.glb` greenery.
  - Floating house labels (*Kos Rina*, *Warung Sari*, *Rumah Pak Budi*) + `!` indicator badge above un-greeted neighbors.
- **Bottom Story Dialogue Bar (`StreetScene.ts`):**
  - Replace full-screen center modal with a sleek translucent dark-glass bottom dialogue panel (`y = 665`) featuring speaker name, role, quote, **`💬 Sapa (+Rp X)`** CTA, and **`Tutup`** button while keeping the living street visible above.
- **Glass Top HUD:** `Hari N • 08.30`, `Saldo: Rp X`, `★ Stars`, and **`📱 HP (Menu)`** button.

## 3. Room Diorama & Modal Spacing Polish (`Room3DView.ts`, `RoomScene.ts`, `MenuScene.ts`)
- **Initial Character Facing (`src/core/character.ts` / `Room3DView.ts`):** Set `createCharacterState` default `rotY = Math.PI * 0.2` (facing camera-front) instead of `Math.PI` (back turned away from camera).
- **Grounded Patio Surround (`Room3DView.ts`):** Add a subtle wider grassy/terrace ground skirt (`9m × 9m` soft sage-cream base) beneath the `4.8m` room diorama so the room sits warmly on the world instead of floating in a flat rectangle void.
- **UI Spacing Polish:**
  - `MenuScene.ts`: Use `formatBalance()` in header; add 6px vertical gap between `Pilih Karakter:` and avatar pills (`y = 220` / `y = 252`); adjust decor rows cleanly (`y = 306 + idx * 58`).
  - `RoomScene.ts`: Move Before/After header labels to `y = 186` and thumbnails to `y = 268` for crisp separation.
