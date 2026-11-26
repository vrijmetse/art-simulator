# Indonesian Life Rhythm Plan: Sleep-to-Recharge, Continuous Clock, Prayer Times & Ramadhan/Lebaran

## Goal
Make `ART Simulator` feel truly alive and distinctly Indonesian by adding a continuous daily clock, bedroom sleep-to-recharge loop, visible rainy weather rhythm, respectful prayer-time reminders (`Waktu Sholat`), and a seasonal `Bulan Ramadhan` + `THR Lebaran` calendar arc inside the 30-day cycle.

## Scope & Architecture

### 1. New Core Module: `godot/src/core/life_rhythm.gd` (`class_name ArtLifeRhythm`)
Pure, deterministic, unit-tested logic (zero Node dependencies except `Time` helpers if any — pure integer `game_minutes` `0..1439`):
- **Clock & Day Phase (`game_minutes`, start of day `06:00` = `360`, Sahur start in Ramadhan `04:30` = `270`):**
  - `format_clock(minutes: int) -> String` -> `"07:30"`, `"18:05"`
  - `get_phase_from_minutes(minutes: int) -> String`:
    - `< 360` -> `"pagi"` (early dawn / Subuh)
    - `360..629` (`06:00–10:29`) -> `"pagi"`
    - `630..869` (`10:30–14:29`) -> `"siang"`
    - `870..1079` (`14:30–17:59`) -> `"sore"`
    - `>= 1080` (`18:00+`) -> `"malam"`
  - `is_late_night(minutes: int) -> bool` (`minutes >= 1290`, i.e., `21:30+`)
- **Indonesian Seasonal Calendar (30-Day Cycle):**
  - `get_season(day: int) -> String`:
    - `cycle_day := ((maxi(1, day) - 1) % 30) + 1`
    - `10..15` -> `"ramadhan"` (*Bulan Puasa / Ramadhan*)
    - `16` -> `"lebaran"` (*Hari Raya & THR Majikan*)
    - else -> `"biasa"` (*Hari Biasa*)
  - `get_thr_bonus_rp(tier_id: String) -> int`: `kamar_kos`: `150000`, `perumahan_45`: `225000`, `cluster_elite`: `300000`.
- **Prayer Times (`Waktu Sholat` — Respectful Toggle `prayer_reminders_enabled: bool = true`):**
  - Schedule (`PRAYER_SCHEDULE`):
    - `subuh`: `285` (`04:45`), `dzuhur`: `720` (`12:00`), `ashar`: `915` (`15:15`), `maghrib`: `1080` (`18:00`), `isya`: `1155` (`19:15`)
  - `check_prayer_trigger(prev_min: int, cur_min: int, prayed_today: Array, enabled: bool) -> Dictionary`
    - Returns `{ "triggered": true, "id": "dzuhur", "label_id": "Dzuhur", "label_en": "Dhuhr" }` cleanly without duplicate triggers.
  - `perform_prayer(save: Dictionary, prayer_id: String, today_day: int) -> Dictionary`
    - Appends `prayer_id` to `prayed_today` (scoped to `prayed_day == day`), grants `+12 Mood`, `+5 XP`, and in `ramadhan` at `maghrib` (`buka_puasa`), also grants `+20 Energy`!
    - Records mission/badge-friendly state without breaking `SaveStore`.
- **Sleep-to-Recharge (`sleep_in_bed(save: Dictionary, owned_upgrades: Array) -> Dictionary`):**
  - Restores `save["energy"]` to `Progression.get_max_energy(save)` (`100`+).
  - Restores `save["mood"]` by `+22` (`+28` if `kasur_empuk` owned, `+32` if `ac_hemat` owned), clamped `0..100`.
  - Advances `day += 1`, resets `game_minutes` to `270` (`04:30`) if next day is `ramadhan` else `360` (`06:00`), clears `prayed_today` for the new day.
  - If next day is `lebaran` (`cycle_day == 16`) and not yet claimed this cycle (`thr_claimed_cycle != cycle_idx`), returns `"thr_bonus_rp"` and credits it once!

### 2. Integration in `progression.gd`, `chore_engine.gd`, `save_store.gd`, `main_game.gd`
- **Persistent Energy:**
  - `Progression.create_initial_save` adds `"energy": 100`, `"game_minutes": 360`, `"prayer_reminders": true`, `"prayed_day": 1`, `"prayed_today": []`, `"thr_claimed_cycle": -1`, `"takjil_claimed_day": 0`.
  - `ChoreEngine.create_shift(tier_id, profile, max_energy, initial_energy = -1)` uses `initial_energy` when `>= 0` (clamped `0..max_energy`) so existing 3-arg calls stay 100% backwards-compatible!
  - `Progression.settle_shift` persists remaining `energy` onto `nxt_save["energy"]` and skips `meal_cost_rp` during `"ramadhan"` daytime (`season == "ramadhan"` -> `meal_cost = 0`, because fasting!).
- **HUD & World Interactions (`main_game.gd`):**
  - **Top-left HUD (`_lbl_clock` / compact line):** shows `H1 • 07:30 ☀` (or `🌧` when raining, `🌙` at night, `+ Puasa` badge in Ramadhan) — zero extra HUD width on `780×437`!
  - **Bedroom Portals (`_enter_home_mode`):**
    - `"exit_street"` (`Keluar Kamar`)
    - `"sleep_bed"` (`Tidur di Kasur` near the bed `Vector3(-1.15, 0.0, -0.75)` -> restores Energy & Mood, advances to next morning!)
    - `"pray_mat"` (`Sholat / Doa` near sajadah spot `Vector3(1.15, 0.0, -0.75)`, visible when `prayer_reminders` is on -> `+12 Mood`, `+5 XP`)
  - **During Shift / Street:**
    - Smooth continuous clock (`1 real s = 2 game min`, paused while modals or onboarding are open!).
    - On prayer time trigger -> cozy toast + quick button in HUD/Menu (`Sholat (+Mood)`): during a shift, clicking/tapping `Sholat` pauses `0.8s`, Majikan says `"Silakan sholat dulu, Mbak!"` (zero trust loss), `+12 Mood`!
    - At `18:00 Maghrib` during `ramadhan` -> `Buka Puasa / Takjil (+20 Energi, +15 Mood)` auto-toast & button!
    - Anti-softlock: trying to enter `Rumah Majikan` when `energy < 20` shows a friendly choice modal: `"Energi tinggal X%! Pulang tidur di kasur dulu (Gratis, Energi 100%) atau tetap kerja?"`

### 3. `SaveStore.sanitize` Compatibility
- Legacy saves missing `energy`, `game_minutes`, `prayer_reminders`, `prayed_day`, `prayed_today`, `thr_claimed_cycle`, `takjil_claimed_day` default cleanly (`energy = max_energy`, `game_minutes = 360`, `prayer_reminders = true`, etc.).

## Adversarial Attack Checklist
1. Could `energy` persistence break any existing `Progression.settle_shift` or `ChoreEngine.create_shift` tests? (Verify 3-arg `create_shift` defaults to full `max_energy`.)
2. Could `energy < 20` or `0 Rp` + `0 energy` cause a player softlock? (Verify bed sleep is ALWAYS free and restores 100% energy + rent grace still safe.)
3. Could prayer triggers or `THR Lebaran` or `Takjil` be farmed infinitely by saving/reloading or entering/exiting rooms? (Verify `prayed_today` + `prayed_day`, `thr_claimed_cycle`, `takjil_claimed_day` idempotency.)
4. Could clock text on `_tl_card` clip or overflow `780×437` mobile HUD?
