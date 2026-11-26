# Plan: Walkable Street Hub (`Keluar Kamar`), NPC Relocation, 0-Chore Exploit Fix & Real `Mood`/`Upgrade` Mechanics

## Goal
Resolve every critical & important issue surfaced by the 3-persona adversarial playtest audit (`deleg_007ed5c2`):
1. Remove uninvited roommates (`Mbak Dewi`) from the player's private bedroom (`MODE_HOME`), add a physical door hotspot (`Keluar Kamar`), and wire the existing 3D Indonesian outdoor street scenes (`kampung_gang.glb`, `kampung_street.glb`, `cluster_elite_street.glb`) as a walkable `MODE_STREET` hub with neighbor chat/daily tips (`Ngobrol`) and a `Masuk Kerja (Shift)` entrance portal.
2. Close the `0-chore` instant-payout exploit (`Progression.settle_shift` returns `Rp 0 / 0 XP / aborted=true` at 0 chores and prorates partial shifts).
3. Activate `Mood` (`Semangat Kerja`) and `KOS_UPGRADES.mood_bonus` so `Upgrade Kamar`, `HP` distractions (`Main Game`, `Telp Pacar`, `Istirahat`), and street `Ngobrol` provide a meaningful risk/reward bonus (`>= 80` mood -> `+15%` chore speed & `+15%` contract tip bonus; `<= 25` -> `-15%` chore speed).
4. Add Day 5–6 Kos Rent countdown reminders, chain Level-Up + Weekly Rent modals on Day 7 without swallowing either, show 4 Skill Levels in `Karier`, and fix `"Maid Dewi"` / `"LV"` localization.

## Files Touched
- `godot/src/core/npc_roster.gd` — Empty `get_home_npcs()` for private bedrooms; add `get_street_config(tier_id)` with verified paving `walk_rect`, `player_spawn`, `portal_home`, `portal_work`, and `street_npcs` (including `Mbak Dewi` + tier neighbors with `>= 1.2m` clearance); clean EN honorifics (`Mbak Dewi`, `Ibu Sari`, `Pak Budi`, `Kakak Maya`).
- `godot/src/core/chore_engine.gd` — Add optional `mood: int = 60` parameter to `effective_duration(chore_id, skill_level, mood = 60)` (`0.85x` at `mood >= 80`, `1.15x` at `mood <= 25`).
- `godot/src/core/majikan_call.gd` — Add `consume_chore_mood(state, delta)` helper; respect initial `mood` passed into shift.
- `godot/src/core/progression.gd` & `godot/src/core/save_store.gd` — Add `"mood": 65` & `"chatted_dates": {}` to save schema + sanitization; add `get_mood_bonus(save)`; fix `settle_shift()` to block `0-chore` payouts (`aborted = true`, `day` unchanged, `Rp 0`, `0 XP`), prorate partial shifts, apply `+15%` morale bonus at `mood >= 80`, and persist recovered end-of-shift `mood`.
- `godot/src/scenes/main_game.gd` — Add `MODE_STREET` alongside `MODE_HOME` and `MODE_SHIFT`, door/portal hotspots (`[E]` + click/button), street neighbor `[E] Ngobrol` (`Neighborhood.claim_tip` + `+12 mood`), visible `Semangat %` indicator on HUD, Day 5–6 rent warning, Level-Up + Rent modal chaining, and Skill Levels in `Karier` modal.
- `godot/tests/run_tests.gd` — Add RED->GREEN TDD assertions for: empty home NPCs, street config bounds & portal/NPC clearances across all 5 tiers, `0-chore` exploit blocked, partial-shift proration, `Mood >= 80` speed + `+15%` payout bonus, `Upgrade Kamar` `mood_bonus`, and `chatted_dates` save round-trip.
