# Global Hit Phase 2 — Living Household Schedules, Moral Micro-Dilemmas & Cultural Notes

**Date:** 2026-11-28
**Goal:** Bring every household interior to life with staggered NPC indoor movement, introduce branching moral micro-dilemmas behind closed doors, and ship an international-friendly Cultural Notes glossary inside Phone OS.

## Scope & Architecture

### 1. Living Indoor NPC Schedules (`godot/src/core/household_schedules.gd`, `main_game.gd`)
- Pure GDScript `ArtHouseholdSchedules`:
  - `WAYPOINTS`: 2-point safe indoor routes per shift NPC (`ibu_melati`, `ibu_tini`, `pak_agus`, `adik_bima`, `ibu_sari`, `pak_budi`, `kakak_maya`, `ibu_citra`, `pak_hendra`, `kakak_nadine`, `mbak_rina`) clamped inside each tier's `walk_rect` with `>= 0.85m` clearance from chore hotspots.
  - `create_runtime_shift_npcs(shift_npcs, tier_id) -> Array`: copies runtime dicts and binds staggered `wait_s`, `wp_idx = 0`, `speed = 0.65`, `is_walking = false`.
  - `step_shift_npcs(runtime_npcs, player_pos, delta, paused: bool)`:
    - Pauses cleanly (`Idle`) and turns gently toward `player_pos` if `paused` or `player` distance `< 1.65m`.
    - Otherwise alternates between resting (`wait_s` in `Idle`) and strolling (`Walk` animation via `StreetPatrols._play_matching_anim`) between `waypoints[0]` and `waypoints[1]`.
- `main_game.gd`: `_start_shift()` initializes `_shift_npcs_data` via `HouseholdSchedules.create_runtime_shift_npcs(...)`; `_process()` ticks `HouseholdSchedules.step_shift_npcs(...)` when `_world_mode == "shift"` (respecting `ui_cover` / active modal pause!). Also updates `_nearest_shift_npc()` to read live `npc["node"].position` or `npc["pos"]`.

### 2. Branching Moral Micro-Dilemmas (`godot/src/core/household_dilemmas.gd`, `save_store.gd`, `progression.gd`, `main_game.gd`)
- Pure GDScript `ArtHouseholdDilemmas`:
  - 5 tier-matched dilemmas (`dilemma_kos_student`, `dilemma_kampung_gosong`, `dilemma_p36_pecah`, `dilemma_p45_curhat`, `dilemma_elite_amplop`), each with 2–3 choices + distinct ID/EN narrative & outcome text.
  - `should_trigger(tier_id, elapsed_s, already_triggered, completed_count, blocked_by_ui_or_event) -> bool`: triggers once per shift when `elapsed_s >= 10.0`, `completed_count >= 1`, and no active modal/call/jemuran conflict.
  - `resolve_choice(save, call_state, shift, dilemma_id, choice_idx) -> Dictionary`: applies exact deltas (`balance_rp`, `xp`, `mood`, `trust`, `energy`), marks `dilemma_id` inside `save["resolved_dilemmas"]` (clamping `xp` bonus if re-encountered so players cannot farm infinite XP!), and returns updated `save`, `call_state`, `shift`, and localized outcome toast.
- `Progression.create_player_save()` adds `"resolved_dilemmas": []`; `SaveStore.sanitize()` validates against `HouseholdDilemmas.DILEMMAS` across JSON round-trip.
- `main_game.gd`: `_open_dilemma_modal(dilemma)` pauses shift call/jemuran timers (`ui_cover` is true while modal is open!) and hides `_btn_modal_close` until the player makes a choice (same non-dismissible guard as weekly rent).

### 3. Cultural Notes Glossary (`godot/src/core/cultural_notes.gd`, `main_game.gd`)
- Pure GDScript `ArtCulturalNotes`:
  - 8 bilingual cultural notes (`kos`, `art`, `thr`, `kasbon`, `jemuran`, `pak_rt`, `mudik`, `warung`).
  - `get_notes(locale: String) -> Array`
- `main_game.gd`: adds a **"Catatan Budaya / Cultural Notes"** entry button inside Phone OS → `Panduan` (`_open_guide_modal`) and `_open_cultural_notes_modal()`, plus direct access from `_open_storybook_modal()`.

## TDD Plan (Stage 3 Red → Green)
Add **Section 47** in `godot/tests/run_tests.gd`:
1. `ArtHouseholdSchedules`: all shift NPCs across all 5 tiers receive valid waypoints inside `walk_rect`; `step_shift_npcs` advances position/state when distant and pauses in `Idle` when player is `< 1.65m` or `paused == true`.
2. `ArtHouseholdDilemmas`: all 5 tiers map to a dilemma; `should_trigger` blocks `< 10s`, `already_triggered`, or `blocked_by_ui_or_event`; `resolve_choice` validates bounds, applies `balance_rp`/`trust`/`mood`/`xp`, deduplicates `resolved_dilemmas` XP farming on repeat, and `SaveStore.sanitize()` preserves `resolved_dilemmas` across round-trip.
3. `ArtCulturalNotes`: all 8 cultural notes return non-empty localized `title` + `body` for both `"id"` and `"en"`.
4. Scene source & compile checks: `main_game.gd` loads cleanly (`!= null`) and passes `-- --smoke-test` + `48/48` Vitest.
