# 1-Month Retention Loops & Android Native APK Plan (`2026-11-26`)

## Part A: 1-Month Retention & Replayability (`godot/src/core/retention.gd` -> `ArtRetention`)
1. **7-Day Real-Calendar Login Streak (`login_streak`, `last_login_date`, `streak_claimed_date`):**
   - `sync_daily_login(save, today_str)`: compares `today_str` (`YYYY-MM-DD`) with `last_login_date` via Unix epoch day math (`Time.get_unix_time_from_datetime_string`).
   - Same day: returns `can_claim_streak` if `streak_claimed_date != today_str`.
   - Consecutive day (`diff == 1`): increments `login_streak` (`1..7`, wrapping cleanly `7 -> 1` after full cycle), sets `last_login_date = today_str`, resets daily missions for `today_str`.
   - Gap (`diff >= 2`) or empty: sets `login_streak = 1`, resets daily missions for `today_str`.
   - `claim_streak_reward(save, today_str)`: idempotent 1x/day reward across 7 escalating tiers (Rp + XP).
2. **Rotating Daily Missions (`daily_missions`: `{date, progress:{...}, claimed:[...]}`):**
   - Deterministic 3 missions per `today_str`:
     - `"m_shifts"` (Complete 2 shifts)
     - `"m_neighbors"` (Greet 3 street neighbors)
     - `"m_calls"` (Answer 2 employer calls promptly)
     - `"m_boosts"` (Use Ketuk Cepat 4 times)
     - `"m_chores"` (Finish 6 chores)
   - `record_mission_progress(save, event_key, amount, today_str)` increments relevant active missions; `claim_mission_reward(save, mission_id, today_str)` validates completion & prevents duplicate claims.
3. **Random Daily Shift Events (`get_shift_event(day, tier_id)`):**
   - Deterministic by `(day, tier_id)` so day replays stay consistent:
     - `"normal"` (no modifier)
     - `"arisan_ramai"` (+35% contract pay, 0.85x call patience)
     - `"hujan_berkah"` (+Rp 10,000 transport bonus, -10% chore energy cost)
     - `"tamu_keluarga"` (+25% shift XP)
4. **Permanent Milestone Badges (`unlocked_badges`):**
   - 6 badges (`first_shift`, `fast_worker`, `friendly_art`, `rent_free`, `dream_seeker`, `elite_star`) evaluated via `evaluate_badges(save)` with one-time `+25 XP` bonus per badge.
5. **Realistic Modest Daily Living Sink (`progression.gd`):**
   - When settling a non-aborted shift on `day >= 3` if `not live_in_room_provided` and `balance_rp >= 15000`, deduct `Rp 8.000` daily meal/transport (`meal_cost_rp`) cleanly (never negative, logged in summary).
6. **`SaveStore.sanitize()` Backward Compatibility:**
   - Sanitize `login_streak` (`0..7`), `last_login_date`, `streak_claimed_date`, `daily_missions` dict, `unlocked_badges` (validated against `BADGES`), and `shift_boost_count` / `calls_answered_count` counters safely for existing saves.

## Part B: Native Mobile Readiness (`project.godot`, `main_game.gd`)
1. Lock landscape handheld orientation (`window/handheld/orientation=0`) in `godot/project.godot`.
2. Safe-area notch padding in `main_game.gd` using `DisplayServer.get_display_safe_area()` scaled cleanly against viewport margins (zero regression on desktop/780x437 web).
3. Android Back button (`NOTIFICATION_WM_GO_BACK_REQUEST`) closes active modal / phone popup first, or opens Menu modal if none are open.
4. Add **`Misi & Streak`** modal (`_open_retention_modal`) reachable from top-right `Misi` / `Menu` + `Karier`, with auto-prompt badge on login.

## Part C: Android `.apk` Export Pipeline (`export_presets.cfg`, `scripts/export_android.sh`)
1. Install ARM64 native `apksigner` & `zipalign` (`apt-get install -y apksigner zipalign`) + extract `android_debug.apk` & `android_release.apk` from official `Godot_v4.7.2-stable_export_templates.tpz` into `~/.local/share/godot/export_templates/4.7.2.stable/`, then remove the `.tpz` archive.
2. Create Android SDK shim dir (`~/.local/share/android-sdk-shim/build-tools/34.0.0/apksigner` -> `/usr/bin/apksigner`) + generate local keystore + add `[preset.1]` (`platform="Android"`, `gradle_build/use_gradle_build=false`, `package/unique_name="id.co.shr.artsimulator"`, `arm64-v8a` + `armeabi-v7a`) in `godot/export_presets.cfg`.
3. Export `build/art-simulator.apk`, verify signature with `apksigner verify`, run full Godot TDD + `--smoke-test` + Vitest + Web export + Coolify deploy + live browser check.
