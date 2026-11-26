# Master Plan: All 4 Clean-Room Immersion Gaps (Time/Weather + 3D Kos Upgrades, Street Traffic + Indonesian Archetypes, Visual Map + Portraits, Settings + Daily Log)

## Architecture & Parallel Module Split
To implement all 4 gaps cleanly in parallel without file collisions, each gap owns an isolated pure-GDScript core module (plus Blender vehicle generator for Gap 2), followed by unified `run_tests.gd` TDD verification, `main_game.gd` integration, visual capture verification, Stage 4 adversarial diff review, Web/PWA export, and live Coolify deploy:

1. **Gap 1 — `godot/src/core/atmosphere.gd` (`ArtAtmosphere`):**
   - Deterministic `get_phase(world_mode, day, shift_elapsed_s)` (`"pagi"`, `"siang"`, `"sore"`, `"malam"`) and `get_weather(day, weather_fx)` (`"cerah"`, `"hujan"`).
   - `apply_lighting(sun: DirectionalLight3D, bounce: DirectionalLight3D, env: Environment, phase: String, weather: String)` — adjusts sun color/energy, sky top/horizon, ambient light without extra assets.
   - `apply_kos_upgrades_visual(stage_root: Node, owned_upgrades: Array)` — toggles existing `kos_room.glb` meshes (`IndoorAC`/`IndoorACVent` for `ac_hemat`, `FanBlade_*`/`Cylinder.006`/`Cylinder.007`/`Sphere`/`Torus.001` for `kipas_angin`, `RiceCookerStand`/`Cylinder.008`/`Cylinder.009` for `magic_com_pro`), upgrades `cover`/`pillow` material tint (`kasur_empuk`), and creates/toggles a clean procedural `RakSepatu` node (`rak_sepatu`).

2. **Gap 2 — `godot/blender/build_vehicles.py` + `godot/src/core/street_traffic.gd` (`ArtStreetTraffic`) + `npc_roster.gd` / `neighborhood.gd`:**
   - Generate lightweight original Indonesian vehicles (`veh_angkot.glb`, `veh_motor.glb`, `< 1500` verts each) in Blender.
   - `ArtStreetTraffic` manages deterministic road traffic lanes for `kampung_street` & `cluster_elite_street` (using `1 mesh + 3 color liveries`) and lane bounds checking so vehicles stay strictly on asphalt (`z >= 2.35`, never hitting sidewalk NPCs or player!).
   - Expand `Neighborhood.NEIGHBORS` & `NpcRoster.get_street_config` with iconic Indonesian archetypes (`pak_rt`, `bang_ojek`, `kurir_paket`, `anak_sekolah`) while preserving `walk_rect` & `>= 1.2m` clearances.

3. **Gap 3 — `godot/src/core/portraits.gd` (`ArtPortraits`):**
   - `get_portrait(speaker_id: String, mood: String) -> ImageTexture` — generates crisp cached 48x48 stylized Indonesian character portraits (`neutral`, `happy`, `strict`) via `Image` at runtime (0 KB `.pck` cost).
   - `get_map_destinations(save: Dictionary, world_mode: String) -> Array` — returns visual *Peta Lingkungan* nodes (*Kamar Kos*, *Jalanan Lingkungan*, *Rumah Majikan*, plus district tiers with XP unlock status & travel action).

4. **Gap 4 — `godot/src/core/settings_store.gd` (`ArtSettings`) + `save_store.gd`:**
   - Sanitizes & manages `gfx_quality` (`"high"` / `"low"`), `weather_fx` (`bool`), and `daily_log` (capped array of max 12 structured entries: `{day, kind, title_id, title_en, delta_rp}`).
   - `apply_graphics_quality(sun: DirectionalLight3D, env: Environment, quality: String)` — toggles shadows/SSAO cleanly for mobile WebGL2 performance.

5. **Integration & Verification (`main_game.gd` + `tests/run_tests.gd`):**
   - Wire all 4 modules into `main_game.gd` (top-right `Peta` + `Menu/Atur` buttons, `Catatan` inside modal, portrait icon inside Call Banner / Rent / Toast, rain particles in street, spinning fan blade when `kipas_angin` owned, `SunLight` + `WorldEnvironment` dynamic lighting).
   - Strict TDD tests in `run_tests.gd` covering all 4 modules, `--smoke-test`, `vitest`, visual screenshots (`kos_upgrades`, `street_traffic`, `peta_modal`), Stage 4 adversarial code review, Web/PWA export, Coolify deploy, and live Chromium WebGL2 verification.
