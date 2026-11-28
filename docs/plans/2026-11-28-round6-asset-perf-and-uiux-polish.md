# Round 6 Plan — Asset Optimization, Draw-Call Batching & Full UI/UX Placement Overhaul

**Date:** 2026-11-28  
**Goal:** Bring every screen (`01..16` UI/Phone/Modals + HUD + 3D World) to `>= 8.5/10` mobile & desktop UI/UX best-practice standards while cutting `.pck` download size from `82 MB` to `<= 58 MB`, converting all 3D textures to VRAM compression (`compress/mode=2`), and batching static stage meshes to collapse per-frame draw calls.

---

## Measured Baselines (`3f90f0b`)
- **Web Export (`web-dist/index.pck`):** `85,785,672` bytes (`81.8 MB`); `251` imported textures (`53.62 MB` / `65.6%`) use `compress/mode=0` (uncompressed bitmaps in `.pck` + GPU RAM).
- **Draw Calls / Surfaces (`audit_meshes.gd`):**
  - `kampung_street.glb`: `764` `MeshInstance3D` / `800` surfaces / `198,060` tris
  - `kos_room.glb`: `229` surfaces / `42,602` tris
  - `kampung_gang.glb`: `169` surfaces / `68,332` tris
  - `room_majikan_living.glb`: `143` surfaces / `62,241` tris
  - `room_kampung_house.glb`: `104` surfaces / `43,333` tris
  - `room_elite_living.glb`: `95` surfaces / `57,013` tris
  - `kamar_art_large.glb`: `94` surfaces / `58,769` tris
- **20-Screen Blind UI/UX Audit (`780x437` Mobile Landscape):**
  - **Critical:** Shift `Call Banner` (`Jawab Cepat!`) collides with `Lv` badge on top-right (`r6_ui_05`, `3/10`).
  - **Important/Major:**
    - `01_title` (`5/10`): Top-left corner stack over mirror, flat CTA hierarchy (`MULAI BARU` identical to `MUAT SAVE`), tiny `Info Terbaru` / `Versi`.
    - `02_onboarding` (`4/10`): 8 rows crammed into ~300px (`24–28px` buttons `< 44px`), cramped 4-col color swatches, shoes clipped at bottom, low-contrast season caption.
    - `03_guide_0` & `07..16` Modals (`3–7/10`): `30–65%` dead vertical space caused by fixed `minf(360.0, ...)` height AND `_clear_modal()` calling `queue_free()` without `remove_child()` before `_fit_modal_scroll_height()`; `Confirm` modal (`3/10`) shows redundant `Batal` + `Tutup`; `Save Slots` (`3/10`) shows `Hapus` on empty Slot 1 (`exists == true` with `onboarding_done == false`); `Settings` (`4/10`) mixes nav/actions/system toggles in one flat list; `Career`/`Wardrobe`/`Map` lack explicit lock/active visual cues; `Dreams`/`Retention` lack progress bars & action pills.
    - `04_home` & `05_shift` (`3–5/10`): `_apply_mobile_safe_area()` only handles `pad_left`; `tc_center` (`offset_left = 230`, `-230`) collides with `_tl_card` (`14..300`) and `_tr_vbox` (`904..1264`); Shift dock uses identical `icon_broom` on both `Cepat! 0/3` and `Batal`; `Ketuk Aksi = Cepat!` doesn't match `Cepat! 0/3` button label; `HP` + `Joystick` + `Courier` crowd bottom-left; bare `Sholat / Doa` `Label3D` collides with player/rug; background HUD stays badged/focusable behind blocking modals; `_process()` updates prompt/dock strings every frame without change-guarding.
    - `06_phone_*` (`4–6/10`): 5-col grid with 9 apps leaves an orphan 10th slot; `Kembali` enabled on Home; `Bank`/`Debt` lack progress bars; `Shop` lacks icons & buy pills; `Chat` shows 50% void; `Debt` has 65% void.

---

## Track A — Asset & Draw-Call Optimization

1. **Blender Static Mesh Batching (`godot/blender/tex_utils.py` + `build_*.py`):**
   - Add `join_static_meshes_by_material(preserve_names: set[str], preserve_prefixes: tuple[str, ...] = ())` in `tex_utils.py` (using `bpy.ops.object.join()` per material signature after applying object scale/rotation transforms, preserving UV maps and mesh names).
   - **Strict runtime preserve set (`preserve_names` — exact match with `atmosphere.gd:4-14`):**
     - `kos_room.py`: all `Atmosphere.AC_NODES`, `Atmosphere.FAN_NODES`, `Atmosphere.RICE_COOKER_NODES`, plus `cover`, `pillow` (read verbatim from `atmosphere.gd`!).
     - Every join batch groups strictly by `(tuple(mat.name), tuple(uv_layer_names))` so `UVMap` + `LightmapUV` (`Mesh.ARRAY_FORMAT_TEX_UV2`) are NEVER dropped or misaligned, and alpha-cutout foliage (`Leaves`, `Flowers`) or transparent meshes (`glass`, `window`, `water`, `pet`) stay separate from opaque batches.
   - **Texture cap in `tex_utils.py`:** Add `cap_exterior_textures(max_px=512)` or `polish_scene_textures_1024(max_px=512)` option for outdoor turf/roof/stone/foliage textures (`turf`, `grass`, `genteng`, `roof`, `batu`, `asphalt`, `leaves`, `bark`, `flower`) while keeping hero fabrics/portraits crisp.
   - Re-export affected GLBs and run `godot4 --headless --import`.
2. **VRAM Texture Compression (`godot/assets/models/*.import`):**
   - Keep `assets/ui/`, `assets/portraits/`, and `assets/lightmaps/` at lossless/high quality.
   - Set `compress/mode=2` (VRAM ETC2/ASTC) on `godot/assets/models/*.import` textures (skipping alpha-cutout `Leaves_NormalTree_C` if compression rings alpha edges; setting `compress/normal_map=1` on `_nrm`/`_normal`/`_Normal` maps), and set `process/size_limit=512` on exterior ground/roof/stone/foliage/blanket/curtain textures.
   - Gate: `web-dist/index.pck <= 60 MB` (target `45–58 MB`), `kampung_street.glb` surfaces `<= 80` (down from `800`), `kos_room.glb` surfaces `<= 45` (down from `229`).

---

## Track B — Complete UI/UX Placement, Ergonomics & Focus Overhaul (`main_game.gd` + `atmosphere.gd`)

1. **Pure-Logic Layout Helpers (`godot/src/core/atmosphere.gd`) + TDD (`godot/tests/run_tests.gd`):**
   - `compute_hud_safe_margins(safe_rect: Rect2, win_size: Vector2, vp_size: Vector2) -> Dictionary`: returns `{left, top, right, bottom}` clamped `[0, 48]`.
   - `compute_top_center_bounds(vp_width: float, tl_width: float, tr_width: float, safe_left: float, safe_right: float) -> Dictionary`: returns `{offset_left, offset_right, max_banner_w}` guaranteeing zero overlap between `tc_center` (`_call_banner` / `_toast_panel`) and `_tl_card` / `_tr_vbox`.
   - `clamp_world_prompt_pos(screen_pos: Vector2, prompt_size: Vector2, vp_size: Vector2, safe_margins: Dictionary) -> Vector2`: keeps `_world_prompt` inside clear playfield (`y` below top HUD and above bottom dock/joystick; never over `_tl_card` or `_tr_vbox`).
   - `should_show_slot_delete(slot_entry: Dictionary) -> bool`: true ONLY when `bool(entry.get("exists", false))` AND `bool(entry.get("onboarding_done", false))`.
2. **HUD Corners, Safe Area & Shift Action Clarity (`godot/src/scenes/main_game.gd`):**
   - Apply all 4 safe-area margins (`left`, `top`, `right`, `bottom`) in `_apply_mobile_safe_area()` to `_tl_card`, `_tr_vbox`, `_br_vbox`, `_hp_bottom_left`, `_joy_base`, `_courier_toast`, `tc_center`, `_dialogue_bar`.
   - Fix `tc_center` width via `compute_top_center_bounds()` (`offset_left = 316 + pad_left`, `offset_right = -356 - pad_right`) AND wrap `_lbl_call_title` (`autowrap_mode = WORD_SMART`, `custom_minimum_size.x = 160`) + compact `_btn_answer` (`44px` tall) so `_call_banner` **never** touches `Lv` or `_tl_card`.
   - Fix Shift dock icons & action clarity:
     - When `_in_shift`: `"shift"` button (`Selesai` / `Pulang` / `Batal`) uses `icon_door` (NOT `icon_broom`!), while `"action"` button (`Kerjakan` / `Cepat! X/3`) keeps `icon_broom`.
     - Sync chore progress bar hint text with exact dock button name: `[Ketuk "Cepat!" = Boost!]` on touch / `[Tekan E = Cepat!]` on keyboard, and confirm `_bar_chore.show_percentage = false`.
   - De-crowd bottom-left & bottom-right dock:
     - Make bottom-right dock sleek (`ic_box = 54x48`, label `60px`, `separation = 6`, scrim padding `8, 4`) — preserves `>= 48px` tap target while reclaiming ~20px vertical bottom clearance above street NPCs' feet.
     - In landscape (`canvas_sz.x >= 920`), align `_hp_bottom_left` cleanly beside `_joy_base` on the bottom baseline (`offset_left = 122 + pad_left`, `offset_bottom = -12 - pad_bottom` when joystick visible, else `14 + pad_left`); in portrait (`canvas_sz.x < 920`), stack `_hp_bottom_left` above `_joy_base` (`offset_left = 14 + pad_left, offset_bottom = -122 - pad_bottom`) so it never collides horizontally with `_br_vbox`. Position `_courier_toast` neatly above `_hp_bottom_left` / `_joy_base` (`offset_left = 14 + pad_left`, `offset_bottom = -124 - pad_bottom` landscape / `-214 - pad_bottom` portrait) ONLY while an active order exists, and hide `_courier_toast` / dock badges whenever `_modal_backdrop` or `_phone_os_wrap` is open.
   - Enforce `custom_minimum_size = Vector2(56, 44)` on `_btn_map`, `_btn_settings`, `_spotlight_btn_ok`, `_spotlight_btn_skip`, and `_courier_claim_btn`.
   - Suppress bare `Sholat / Doa` / `Tidur` `Label3D` clutter when `player` is overlapping (`distance < 0.9m`) or when `_world_prompt` is visible or `_modal_backdrop.visible`.
   - Cache `_last_prompt_key` and `_last_action_label_key` in `_process()` to eliminate per-frame string/layout churn.
3. **Title (`01`) & Onboarding (`02`) Ergonomics (`godot/src/scenes/main_game.gd`):**
   - **Title (`01`):** Place logo + CTA buttons inside a clean translucent dark-obsidian glass card (`Color(0.06, 0.08, 0.12, 0.84)`, gold border) anchored comfortably at bottom-left (`offset_bottom = -20`, `offset_left = 24`) for thumb reach while leaving center-right 3D room & character showcase unobstructed; distinct primary CTA gold fill (`MULAI BARU` when no save, `LANJUTKAN` when save exists) vs dark secondary buttons; enlarge bottom-right `Info Terbaru` + `Versi 1.5 (HD)` (`44px` touch target, readable `12px` badge).
   - **Onboarding (`02`):** Adjust camera framing so character's full body + shoes sit cleanly inside left frame (`cam.look_at` shifted `0.08m` lower); wrap right-panel controls inside a mandatory `ScrollContainer` inside the card with **`>= 44px` height on EVERY button**, 2×2 grid for the 4 Daster colors (instead of cramped 4-in-1 row!), clean `"Cepol (Daster)"` / `"Hijab (Bergo)"` labels, high-contrast season badge, and smaller secondary `"Kembali"` button in top header row next to `EN`/`ID` (no full-width back trap right under `"Mulai Kerja!"`).
4. **Modals (`03`, `07..16`) & Phone OS (`06_*`) Polish:**
   - **Immediate child removal (`_clear_modal` & `_render_phone_app`):** Call `_modal_list.remove_child(c); c.queue_free()` so `_fit_modal_scroll_height()` measures true current content height on the same frame and removes the 30–65% dead vertical void across all modals! Set initial `_modal_scroll` min-height to `0` (`clampf(content_h, 80.0, max_h)`) instead of hardcoded `360.0`.
   - **Confirm Purchase (`10`):** Hide `_btn_modal_close` (`_btn_modal_close.visible = false`) so `Batal` and `Ya, Beli` are the only two clear bottom CTAs; frame item name, cost, and remaining balance in an emphasized summary card.
   - **Save Slots (`16`):** Only render `Hapus` button when `Progression/SaveStore` `should_show_slot_delete(entry)` is true (`onboarding_done == true`), keeping empty slots full-width and symmetric.
   - **Settings (`15`):** Group into 3 visual section headers (`Akun & Catatan`, `Aktivitas & Pengingat`, `Pengaturan Sistem`) and separate destructive `Reset Career Save` cleanly at the bottom.
   - **Career (`07`), Wardrobe (`08`), Kos (`09`), Retention (`11`), Dreams (`12`), Storybook (`13`), Map (`14`):**
     - Add `🔒` prefix/badge on locked tiers/outfits/chapters; add `"✓ Aktif"` pill styling on active tier/map district; fix `Koral Hangat` contrast (`dark_ink` text when luminance `> 0.45`); add right-aligned `"Klaim"` / `"Wujudkan"` / `"Baca"` / `"Beli"` cues and wallet/target progress bars in `Retention`, `Dreams`, `Bank Desaku`, and `Buku Kasbon`; add player mini-portrait preview in `Wardrobe`.
   - **Phone OS (`06_*`):** Add 10th app (`Catatan Harian` -> `_open_log_modal()`) so the 5×2 landscape grid is **100% symmetric with zero empty slot** (`3×3+1`? Wait: in portrait `grid.columns = 2` -> 5×2, or `3×3` = 9 apps + `grid.columns = 3` in portrait & `5` in landscape with 10 apps = `5×2` landscape AND `2×5` or `3×3`? Use `5` cols landscape = `5×2 = 10` symmetric, and `2` cols portrait = `2×5 = 10` symmetric!); disable `Kembali` on `"home"`; add progress bars to `Bank Desaku` and `Buku Kasbon`.
5. **Focus-on-Open & Modal Input Trapping (`game-ui-ux`):**
   - Add recursive `_set_hud_focus_enabled(enabled: bool)` setting `c.focus_mode = Control.FOCUS_NONE` (caching prior `focus_mode` in metadata) on `_tl_card`, `_tr_vbox`, `_br_vbox`, `_hp_bottom_left` while any modal, Phone OS, Title, or Onboarding is active, and call `grab_focus()` on the primary button when opening Title, Onboarding, Modals, and Phone OS.

---

## Verification Gates
1. **TDD (`run_tests.gd`):** Write FAILING tests first for `compute_hud_safe_margins`, `compute_top_center_bounds`, `clamp_world_prompt_pos`, `should_show_slot_delete`, `kos_room.glb` preserved upgrade node names + `ARRAY_FORMAT_TEX_UV2` on lightmapped GLBs, and `index.pck` / texture import constraints. Run `run_tests.gd`, `--smoke-test`, and `npm test` (`vitest`).
2. **Full Visual Re-Audit:** Re-capture ALL 20 UI screens (`capture_all_screens.gd`) + ALL 12 World screens (`capture_all_world.gd`) + 15-char lineup (`capture_chars_3d.gd`) at `780x437` and `1280x720`, inspect via `vision_analyze` + blind subagent QA until **every single screen scores `>= 8.5/10`**.
3. **Stage 4 Code Review + Export Gate (`index.pck <= 60 MB`, Android APK signed) + Coolify Live Deploy & Browser Verify.**
