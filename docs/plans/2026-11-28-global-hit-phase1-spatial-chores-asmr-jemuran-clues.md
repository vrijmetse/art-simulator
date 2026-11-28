# Global Hit Phase 1 — Spatial Mess Transformation, ASMR Foley, Jemuran Chaos & Household Clues

**Date:** 2026-11-28
**Goal:** Transform *ART Simulator (Cozy Homekeeper)* from progress-bar chores into a tactile, replayable, clip-worthy cozy life sim with visible before/after room cleanup, layered ASMR foley, the signature *"Jemuran Rain Rescue!"* chaos hook, and discoverable human micro-stories behind closed doors.

## Scope & Architecture (4 Modules + Main Integration)

### 1. Spatial Mess-to-Spotless Transformation (`chore_engine.gd`, `chore_hotspot.gd`, `main_game.gd`)
- **`ChoreEngine.compute_room_cleanliness(shift, active_chore_id, active_progress_ratio) -> int`:**
  - Returns `0..100` integer percentage across `assigned_ids`, interpolating the active chore smoothly (`0.0..1.0`).
- **`ChoreHotspot` (`godot/src/scenes/chore_hotspot.gd`):**
  - `setup(chore_id, label_id, label_en, pos)` spawns `3–4` chore-specific low-poly 3D mess chunks (`_mess_nodes`) at calibrated prop height (`make_bed` pillows/cloth `y=0.45`, `wash_dishes` bowls/foam `y=0.72`, `cook_rice` pan veggies/steam `y=0.72`, `iron_laundry` crumpled folds `y=0.55`, `sweep_floor` dust/leaf clumps `y=0.04`, `water_plants` dry specks `y=0.32`).
  - `set_progress(ratio: float)` pops chunks off smoothly as `ratio` crosses thresholds (`0.25, 0.50, 0.75, 0.95`) with a scale-down tween; `mark_completed()` clears all remaining mess chunks cleanly.
- **`main_game.gd`:**
  - Feeds live `set_progress(ratio)` during active chores.
  - Displays `Kebersihan: XX%` / `Cleanliness: XX%` in the top-left shift HUD checklist.
  - Displays `0% → 100% BERKILAU!` (`0% → 100% SPARKLING CLEAN!`) cleanliness badge on Shift Summary.

### 2. Per-Chore Procedural ASMR Foley (`audio_synth.gd`, `main_game.gd`)
- Add 4 procedural `AudioStreamWAV` builders to `ArtAudioSynth`:
  - `make_dish_splash()` (ceramic clink + soft water shimmer)
  - `make_wok_sizzle()` (filtered high-band sizzle + rice cooker *klik*)
  - `make_cloth_snap()` (crisp linen snap + warm harmonic overtone)
  - `make_thunder_rumble()` (deep low-pass storm roll for Jemuran Rain Rescue)
- Wire `_play_chore_foley(chore_id)` in `main_game.gd` on chore start and non-perfect `Cepat!` boosts.

### 3. "Jemuran Rain Rescue!" Mid-Shift Chaos Event (`godot/src/core/jemuran_event.gd`, `main_game.gd`)
- Pure GDScript `ArtJemuranEvent`:
  - `should_trigger(tier_id, elapsed_s, already_triggered, completed_count, total_count) -> bool` (eligible tiers: `kampung`, `perumahan_36`, `perumahan_45`, `cluster_elite`; triggers once per shift after `16.0s` when `completed_count >= 1` and shift not yet complete).
  - `create_state(pos: Vector3) -> Dictionary` (`active: true, remaining_s: 15.0, pos: pos, rescued: false, failed: false`).
  - `tick_state(state, delta) -> Dictionary` (decrements `remaining_s`; expiry sets `active=false, failed=true`).
  - `rescue(state) -> Dictionary` (`active=false, rescued=true, bonus_rp: 15000, xp: 15, mood_bonus: 8, trust_bonus: 6`).
- In `main_game.gd`:
  - Spawns a cyan/amber pulsing `JemuranHotspot` at tier-safe terrace/doorway coords (`pos` within `walk_bounds`), plays `_wav_thunder`, shows countdown prompt/toast, and lets `E`/Action rescue it when near (`< 1.55m`). Cleanly cleared on `_enter_home_mode()` / `_enter_street_mode()`.

### 4. Hidden Household Clues (`godot/src/core/household_clues.gd`, `save_store.gd`, `progression.gd`, `main_game.gd`)
- Pure GDScript `ArtHouseholdClues` with 10 curated Indonesian household micro-stories (2 per tier across all 5 tiers):
  - `kamar_kos`: `clue_melati_foto`, `clue_kos_nota`
  - `kampung`: `clue_bima_crayon`, `clue_agus_bengkel`
  - `perumahan_36`: `clue_sari_tiket`, `clue_budi_kopi`
  - `perumahan_45`: `clue_rina_surat`, `clue_hendra_piagam`
  - `cluster_elite`: `clue_citra_lukisan`, `clue_elite_wisuda`
- `pick_clue_for_shift(tier_id, unlocked_clues, day) -> Dictionary`
- `collect_clue(save, clue_id) -> Dictionary` (idempotent guard: rejects duplicate `clue_id`, appends to `unlocked_clues`, awards `+20 XP`, `+5 mood`).
- `Progression.create_player_save()` initializes `"unlocked_clues": []`; `SaveStore.sanitize()` validates every entry against `HouseholdClues.CLUES` and preserves on round-trip.
- `main_game.gd`: spawns golden curio glint `ClueMarker` near a safe stage point during shifts; inspecting (`E`/Action `< 1.45m`) or finishing shift summary collects + toasts the micro-story, and Phone OS `Cerita` (`story`) displays all discovered **Jejak Rumah (Household Clues)**!

## TDD Plan (Stage 3 Red → Green)
Add **Section 46** in `godot/tests/run_tests.gd`:
1. `ChoreEngine.compute_room_cleanliness`: `0%` start -> smooth `~50%` mid-shift -> `100%` all done; guards empty `assigned_ids`.
2. `ArtAudioSynth`: `make_dish_splash()`, `make_wok_sizzle()`, `make_cloth_snap()`, `make_thunder_rumble()` return non-empty `AudioStreamWAV`.
3. `ArtJemuranEvent`: `should_trigger` blocks `kamar_kos` and early `<16s` / `already_triggered`; `tick_state` expires cleanly (`failed=true`); `rescue` grants `+Rp 15.000`, `+15 XP`, `+8 mood`, `+6 trust` and prevents double-rescue.
4. `ArtHouseholdClues` & `SaveStore`: all 5 tiers have clues; `collect_clue` awards `+20 XP` once and blocks duplicate claims; `SaveStore.sanitize()` preserves valid clues and strips bogus IDs across JSON round-trip.
5. Scene source & compile checks: `ChoreHotspot.setup` + `set_progress`, `main_game.gd` loads cleanly (`!= null`) and passes `-- --smoke-test` + `48/48` Vitest.
