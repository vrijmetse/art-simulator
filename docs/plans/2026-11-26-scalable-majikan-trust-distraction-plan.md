# ART Simulator — Scalable Majikan Profiles, Distractions & Modular Rooms Plan

**Date:** 2026-11-26  
**Scope:** Godot 4.7.2 (`godot/src/core/`, `godot/tests/run_tests.gd`, `godot/blender/`)  
**SOP:** Adversarial Plan Review -> Red-Green-Refactor TDD -> Per-Asset Review (`>= 8.5/10`) -> Adversarial Pre-Commit Review.

---

## 1. Core Architectural Pillars (Scalable & Data-Driven — Adversarial Review Hardened)

### A. Data-Driven Personalities & Majikan Profiles (`godot/src/core/majikan_profiles.gd`)
Zero `if/elif` personality switches in gameplay logic. All behavior lives in `PERSONALITIES` & `PROFILES`:
- **`PERSONALITIES` table:**
  - `"ramah"`: `call_patience_s = 14.0`, `miss_trust_penalty = 12`, warm gentle Bahasa Indonesia warning templates
  - `"ramai"`: `call_patience_s = 11.0`, `miss_trust_penalty = 18`, hurried family-chaos warning templates
  - `"perfeksionis"`: `call_patience_s = 7.5`, `miss_trust_penalty = 25`, strict crisp warning templates
- **`PROFILES` table (keyed by unique `id`, queried via `get_profile(id)` and `get_profiles_for_tier(tier_id) -> Array`):**
  - `"ibu_kos_melati"` (`tier_id = "kamar_kos"`): Ibu Kos hiring ART to clean neighboring/vacant kos rooms (`kamar_art_variant = "none"`, `work_scene = "res://assets/models/kos_room.glb"`).
  - `"pak_hendra_kampung"` (`tier_id = "kampung"`): Kampung homeowner (`kamar_art_variant = "none"`, `work_scene = "res://assets/models/kampung_gang.glb"`).
  - `"keluarga_budi_36"` (`tier_id = "perumahan_36"`): Type 36/72 family (`kamar_art_variant = "none"`, `work_scene = "res://assets/models/kampung_street.glb"`).
  - `"bu_ratna_45"` (`tier_id = "perumahan_45"`): Perfeksionis Type 45/90 (`kamar_art_variant = "small"`, `kamar_art_scene = "res://assets/models/kamar_art_small.glb"`).
  - `"keluarga_wijaya_elite"` (`tier_id = "cluster_elite"`): Elite 2-story cluster (`kamar_art_variant = "large"`, `kamar_art_scene = "res://assets/models/kamar_art_large.glb"`).

### B. Distraction vs Majikan Call State Machine (`godot/src/core/majikan_call.gd`)
Pure functional GDScript state transitions with strict invariants:
- **Activity States & Mood Clamping (`0..100`):** `"working"` | `"resting"` (+6 mood) | `"playing_game"` (+14 mood, `+2.0s` call reaction delay) | `"calling_boyfriend"` (+18 mood, `+2.5s` call reaction delay).
- **Single Unambiguous Penalty Math:** Only initial `call_elapsed_s` receives the distraction reaction delay (`0.0s` if working/resting, `+2.0s` if playing game, `+2.5s` if calling boyfriend). `tick_call(state, dt)` advances `call_elapsed_s` by clamped `clampf(dt, 0.0, 2.0)` (no double drain).
- **Guards & Clamping:**
  - `start_call(state, reason)`: no-op if `active_call == true` or `fired == true`.
  - `respond_to_call(state)`: no-op if `active_call == false` or `fired == true`. Clears `active_call = false` immediately (prevents double-reward/resurrection).
  - `trust` clamped `[0, 100]`; `final_payout_rp(state) = maxi(0, base_pay_rp + tip_bonus_rp - pay_deduction_rp)`.
  - `start_new_shift(profile)` resets `warnings = 0`, `fired = false`, `active_call = false`, `tip_bonus_rp = 0`, `pay_deduction_rp = 0`, and restores `trust = max(50, profile.initial_trust)` for recovery after firing!

### C. Visual Asset & Modular Room Plan (V13+ -> Modular Interiors)
1. **V13 Street & Character Polish (Finish Asset Gate `>= 8.5/10`):**
   - `Ibu Sari`: hide/remove underlying `casual-2-female` `Hair` triangles inside the `Hijab` volume so zero hair spikes poke out.
   - `Sari ART`: use `casual-2-female.glb` (short-sleeve everyday tee, modest & authentic Indonesian ART starter) + keep `char_art_pro.glb` with apron for Tier 3+.
   - CC0 `sedan.glb` & `van.glb`: tint `windshield`/`window`/`glass` materials dark glossy blue-black and remove flat black ground decal boxes.
   - Capture & verify `kampung_gang.glb` (`Gang Kampung`) alongside street/room.
2. **Modular Interior Scenes (Next after V13 Gate):**
   - **`room_majikan_living.glb`:** Employer Living Room + Dining/Kitchen counter where cleaning tasks + Majikan calls actually happen.
   - **`kamar_art_small.glb` & `kamar_art_large.glb`:** Small vs spacious live-in ART rooms reflecting the employer's house tier and personality.

---

## 2. Red-Green TDD Checklist
1. `tests/run_tests.gd`: Test `MajikanProfiles` lookup by `tier_id` & `kamar_art_variant` (`none` for `perumahan_36`, `small` for `perumahan_45`, `large` for `cluster_elite`).
2. `tests/run_tests.gd`: Test `MajikanCall.apply_distraction` (`playing_game`, `calling_boyfriend` boost mood, clamped `0..100`).
3. `tests/run_tests.gd`: Test `MajikanCall.respond_to_call` in-time -> `+trust`, `+tip_bonus_rp`; missed call while `calling_boyfriend` -> `-trust`, `warnings += 1`, `pay_deduction_rp > 0`, Indonesian distraction-specific warning tag; 3 missed calls / `trust <= fire_threshold` -> `fired == true`.
4. `tests/run_tests.gd`: Verify payout floor `max(0, base_pay - pay_deduction)` and integer IDR invariants.
