# Warung-Life Parity & Game Feel Sprint Plan (`2026-11-26`)

## Goal
Close every real bug, economy quirk, and game-feel gap identified in the 3-persona adversarial review (`deleg_03c6c45e`) so **ART Simulator (*Cozy Homekeeper*)** matches or exceeds *Warung Life Simulator* across tactile shift loop, progression math, NPC life, Tier 1 room distinction, dynamic portraits, 780x437 mobile layout, and procedural audio.

## Files & Architecture

### Paket 1: Real Bugs, Economy & Active Tactile Shift Loop
1. **`godot/src/core/majikan_call.gd` + `godot/src/core/progression.gd`**
   - Update `MajikanCall.create_state(profile: Dictionary, initial_mood: int = 50)` so shift start mood uses `Progression.get_shift_starting_mood(save)` (`clampi(int(save.get("mood", 60)) + get_mood_bonus(save), 35, 100)`), ensuring purchased kos upgrades and wishlist items genuinely boost shift speed (`>= 80` = `0.85x` duration) and contract tips (`+15%`)!
   - In `Progression.settle_shift()`, compute `nxt_save["mood"] = clampi(maxi(45, shift_mood), 25, 100)` (no double-adding `get_mood_bonus` on every shift end).
   - Add `Progression.get_level_tip_bonus(xp: int) -> float` (`1.0 + float(level_from_xp(xp) - 1) * 0.04`, capped at `+0.32`) and include it in `get_tip_bonus_multiplier(save)` so **every intermediate level** (Lv 2, 3, 4, 5, 6...) increases contract income!
2. **`godot/src/core/career_tiers.gd`**
   - Align `perumahan_45.min_level = 4` (matches `level_from_xp(600) == 4`) and `cluster_elite.min_level = 6` (`level_from_xp(1400) == 6`).
3. **`godot/src/core/neighborhood.gd` + `godot/src/core/npc_roster.gd`**
   - Add dedicated entries in `Neighborhood.NEIGHBORS` for `"ibu_melati"`, `"mbak_dewi"`, `"pak_agus"`, `"ibu_citra"`, `"pak_hendra"`, `"kakak_nadine"` so every street NPC ID in `NpcRoster.get_street_config()` maps 1:1 to their real character dialogue and portrait!
   - Adjust `Neighborhood.claim_tip` XP from `10` -> `4` so chatting with neighbors supplements rather than out-scaling shifts.
   - Add `NpcRoster.get_shift_npc_reaction(npc_id: String, locale: String)` for interactive `[E]` shift NPC greetings (`+4 Trust`, `+6 Mood`, 1x per shift per NPC).
4. **`godot/src/core/chore_engine.gd`**
   - Add `CHORE_TOOLS` mapping (`sweep_floor -> "broom"`, `make_bed -> "duster"`, `wash_dishes -> "sponge"`, `cook_rice -> "spatula"`, `iron_laundry -> "iron"`, `water_plants -> "watering_can"`) and `TAP_BOOST_SECONDS := 0.65`, `TAP_BOOST_BONUS_RP := 1500`.

### Paket 2: Tier 1 Distinct Interior, 3D Props, Mobile 780x437 HUD, Portraits & Audio
5. **`godot/blender/build_kos_neighbor_room.py` -> `godot/assets/models/kos_neighbor_room.glb`**
   - Build distinct Tier 1 Shift neighbor room (`<= 4,500` verts, mint-green plaster, terracotta accent rug, mirrored bed/desk/plant arrangement so `ibu_kos_melati.work_interior_scene` is visually distinct from player's `kos_room.glb`).
   - Update `godot/src/core/majikan_profiles.gd` (`ibu_kos_melati.work_interior_scene = "res://assets/models/kos_neighbor_room.glb"`).
6. **`godot/src/core/street_patrols.gd`**
   - Add `sync_chore_tool(player_node: Node3D, tool_id: String)` to attach/toggle lightweight 3D chore tools in hand while cleaning and hide them on finish.
   - Extend `step_patrols(..., is_raining: bool = false)` to call `sync_player_umbrella(node, is_raining)` on patrolling street NPCs too.
7. **`godot/src/core/portraits.gd`**
   - Add `get_player_portrait(skin_hex: String, shirt_hex: String, ob_style: String, mood: String = "neutral")` + entries for new NPC IDs (`mbak_dewi`, `pak_agus`, `kakak_nadine`, `ibu_tini`) so player portraits dynamically match chosen skin tone, outfit color, and hijab/cepol!
8. **`godot/src/core/audio_synth.gd`**
   - Extend `make_cozy_bgm_loop()` to a 16-second A/B pentatonic phrase (`352,800` samples, `LOOP_FORWARD`, zero-click edge fade).
   - Add `make_ui_click()`, `make_door_chime()`, `make_chore_tick()`, `make_footstep_tick()`.
9. **`godot/src/scenes/main_game.gd` + `godot/src/scenes/player_controller.gd`**
   - Add Tap-Boost during active chores (`[E]` / `Space` / `_btn_action` with `0.35s` cooldown, plays `make_chore_tick()`, awards `+1500 Rp` bonus when boosted >= 2x).
   - Project floating `+Rp / +XP` world popup on chore completion + one-shot golden `CPUParticles3D` sparkle burst + shift NPC reaction!
   - Support interacting with nearby Shift NPCs (`[E]` / tap) when not standing on a chore hotspot, and auto-start chore on `arrived_at_target` when player taps directly onto a chore hotspot!
   - Compact `_call_banner` (`_bar_call` `132px`) & bottom-right dock spacing so `780x437` has zero horizontal clipping or joystick overlap; play subtle `make_footstep_tick()` while moving, `make_door_chime()` on portal transitions, and `make_ui_click()` on buttons.

## Verification Plan
- **TDD First (Red -> Green):** Add failing tests in `godot/tests/run_tests.gd` for `MajikanCall.create_state` initial mood, `Progression.get_shift_starting_mood` & `get_level_tip_bonus`, `CareerTiers.min_level` alignment, 1:1 `NpcRoster` <-> `Neighborhood` IDs, `ChoreEngine.CHORE_TOOLS`, `StreetPatrols.sync_chore_tool`, `Portraits.get_player_portrait`, and 16s BGM + new SFX.
- **Visual & Live Verification:** Capture headless renders (`kos_neighbor_shift.png`, `street_rain_umbrellas.png`, `mobile_780x437_call.png`), run Stage 4 adversarial code review, export `web-dist/`, deploy to `https://game.shr.co.id/`, and verify live in Chromium.
