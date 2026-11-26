# Plan: Remaining Polish Gaps (Wishlist Impian ART, Bab Cerita + Tutorial Hari 1, Warga Berjalan + Payung Hujan, & Musik Latar)

## Scope
Implement the final 4 polish/content gaps identified against the full asset taxonomy:
1. **Wishlist (*Impian ART*), Story Chapters (*Bab Cerita*), & Day-1 Guided Tutorial (`godot/src/core/wishlist_story.gd`):**
   - 4 long-term `Rp` goals (`kirim_kampung`, `hp_baru`, `tabung_kontrakan`, `motor_matic`) awarding prestige XP & permanent `mood` boost (`Progression.get_mood_bonus` includes wishlist mood!).
   - 5 tier chapter story cards (`STORY_CHAPTERS`) shown once when reaching each tier (`seen_chapters`).
   - 4-step Day-1 non-blocking tutorial banner (`tutorial_step` `0..4`) guiding `Keluar Kamar` -> `Sapa Tetangga / Masuk Rumah Majikan` -> `Kerjakan Tugas [E]` -> `Selesai Shift`, with one-tap Skip.
2. **Strolling Street Citizens & Rain Umbrella (`godot/src/core/street_patrols.gd`):**
   - Smooth sidewalk patrol movement (`step_patrols`) for patrolling street NPCs (`pak_rt`, `kurir_paket`, `anak_sekolah`, `bang_ojek`), switching `Walk`/`Idle` animations and pausing when player approaches (`< 1.8m`) so chatting never chases a moving target.
   - Procedural 3D Indonesian Umbrella (`UmbrellaProp`) via `sync_player_umbrella(player, active)` automatically visible when walking outside in rain (`_world_mode == "street" and _cur_weather == "hujan"`).
3. **Cozy Procedural BGM & Rain Ambient (`godot/src/core/audio_synth.gd`):**
   - `make_cozy_bgm_loop()` (`AudioStreamWAV.LOOP_FORWARD`, 8s pentatonic warm melody) + `make_rain_loop()` (`LOOP_FORWARD`, 3s soft rain ambient), with independent BGM toggle inside `Menu` and muted cleanly when `_muted == true`.
4. **Save Schema & Integration (`progression.gd`, `save_store.gd`, `main_game.gd`, `tests/run_tests.gd`):**
   - Sanitize `unlocked_wishlist`, `seen_chapters`, `tutorial_step` (`0..4`), and `bgm_enabled` in `SaveStore.sanitize()`.
   - Add `Impian` button inside `Karier` / `Menu` (or bottom dock? Keep HUD clean: `Impian` inside `Menu` + `Karier` header, OR replace nothing on dock — add `Impian (Wishlist)` inside `Peta`/`Menu` AND a compact `Impian` quick-pill in `Karier` & `Menu` so mobile HUD never overflows!).
   - Full RED -> GREEN TDD tests in `run_tests.gd`, visual capture of Rain + Umbrella + Strolling NPCs + Wishlist/Story modal, Stage 4 adversarial review, Web/PWA export, Coolify deploy, and live browser verify.
