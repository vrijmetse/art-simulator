# ART Simulator — Round 1 Benchmark Gap-Closure Plan (`Warung Life` Parity & Polish)

**Goal:** Close every visual, UX, UI, portrait, prop-density, and core-loop gap identified across the 18 *Warung Life Simulator* benchmark screenshots while keeping 100% authentic Indonesian ART (*Asisten Rumah Tangga*) identity, strict Bahasa Indonesia / English separation, and Godot 4.7.2 `gl_compatibility` / WebGL2 / Android performance.

**Approved Architecture & Constraints:**
- Single Godot `4.7.2` (`gl_compatibility`) codebase, `res://assets/portraits/` and `res://assets/ui/` (never `assets/textures/`, which is excluded by `godot/export_presets.cfg`).
- Strict strict-TDD (`Red -> Green -> Refactor`) in `godot/tests/run_tests.gd` + `npx vitest run` + `xvfb-run` `gl_compatibility` visual verification + Stage 4 adversarial review.
- No marketplace drift, no mixed ID/EN strings on the same surface, "Gratis" for zero-cost items, integer IDR.

---

## Stage 2 Adversarial Review Safeguards (Locked Before Coding)
- `run_tests.gd` portrait checks (`615`, `738`) updated to support `256x256` Cycles PNGs (`>= 48`) alongside `48x48` procedural fallback.
- `_ready()` in `main_game.gd` bypasses Title Screen whenever `_smoke_mode` or `_capture_path != ""` (unless `--capture-title` is passed).
- Economy exploit guards: `send_remittance` rejects `amount_rp <= 0`, `amount_rp > balance_rp`, and caps total remittance XP/mood grant once `kirim_kampung` unlocks; `checkout_supply_cart` rejects empty carts/unknown IDs/`qty <= 0`; `claim_courier_delivery` requires `remaining_s <= 0.01` and removes order atomically; `record_kasbon` rejects `amount_rp <= 0` and enforces `MAX_KASBON_DEBT_RP = 100000` unpaid total cap.
- `save_store.gd` clamps `slot` to `1..SLOT_COUNT` (`1..3`) and mirrors Slot 1 to `DEFAULT_PATH`.
- `sleep_in_bed` / day advance completes pending `courier_orders` (`remaining_s = 0.0`).
- Mobile landscape (`780x437`): Smartphone OS clamps height (`min(vp_y - 24, 520)`) with `ScrollContainer` app grid; bottom dock hides while full-width Dialogue Bar is active; Spotlight tooltips clamp inside viewport bounds.
- Blender Cycles portraits (`render_portraits_and_icons.py`): reset factory settings per `.glb`, `samples=24`, `use_denoising=False` (Blender 4.0.2 host lacks OIDN).

## Phase 1 — Core Logic & Persistence (Pure GDScript + RED/GREEN TDD)
1. **`godot/src/core/save_store.gd`:**
   - Add multi-slot save/load helpers (`SLOT_COUNT = 3`, `get_slot_path(slot: int)`, `save_to_slot(save, slot)`, `load_from_slot(slot)`, `list_save_slots()`, `delete_slot(slot)`) while preserving `DEFAULT_PATH = "user://save_v1.json"` (Slot 1 mirrors `DEFAULT_PATH` for seamless backward compatibility).
   - Sanitize new fields: `remittance_sent_rp` (int `>= 0`), `remittance_deadline_day` (int `>= 1`, default `10`), `courier_orders` (array of sanitized active delivery dicts `{id, label_id, label_en, remaining_s, item_id}`), `debt_book` (array of `{id, who, amount_rp, day, paid}`), `guide_seen` (bool; migrated `true` if `completed_shifts > 0`).
2. **`godot/src/core/wishlist_story.gd`:**
   - Add `get_remittance_goal_status(save, locale)` tracking `kirim_kampung` (`target_rp: 150000`, `sent_rp`, `remaining_rp`, `deadline_day: 10`, `days_left`, `completed`).
   - Add `send_remittance(save, amount_rp)` deducting `balance_rp`, incrementing `remittance_sent_rp`, and auto-unlocking `kirim_kampung` + XP/mood bonus when `remittance_sent_rp >= 150000`.
   - Add `get_intro_cutscene_beats(player_name, locale)` (3 emotional beats: 1. `Ibu di Kampung (Telepon)` incoming call needing Rp 150.000 school/family help by Day 10; 2. Narrator establishing Sari's move to the kos; 3. Ibu Melati welcoming Sari to Kamar Kos).
   - Add `get_onboarding_guides(save, locale)` (`Panduan 1/2`: Bank Desaku remittance goal & deadline; `Panduan 2/2`: Shift, Chores, & HP workflow).
3. **`godot/src/core/progression.gd`:**
   - Add `preview_balance_after(save, cost_rp) -> Dictionary` (`can_afford`, `balance_before`, `cost_rp`, `balance_after`).
   - Add `SUPPLY_SHOP_ITEMS` (consumable household/self-care supplies ordered via Smartphone `Belanja`: `kopi_tubruk`, `vitamin_energi`, `detergen_wangi`, `parfum_setrika`, `paket_sembako`) + `checkout_supply_cart(save, cart_dict)` creating an async courier delivery timer (`courier_eta_s: 16.0`) and `claim_courier_delivery(save, order_id)` granting energy/mood/shift-boost buffs.
   - Add `DEBT_BOOK` helpers (`record_kasbon`, `pay_kasbon`) for optional neighborhood/warung credit ledger (`Buku Catatan / Kasbon`).
   - Add `get_spotlight_tutorial_steps(locale)` (4 interactive spotlight steps: `step 0` -> `Mulai Shift`, `step 1` -> `TUGAS` dropdown, `step 2` -> `HP`, `step 3` -> `Upgrade Kamar`).

## Phase 2 — High-Res 3D Cycles Bust Portraits & Painterly UI Icons
1. **`godot/blender/render_portraits_and_icons.py`:**
   - Load each of our 15 MakeHuman `.glb` characters (`char_art`, `char_art_hijab`, `char_ibu`, `char_bapak`/`char_budi`, `char_pak_rt`, `char_bu_rt`, `char_ojek`, `char_kurir`, `char_pelajar`, `char_dewi`, `char_kakak`, `char_hendra`, `char_rina`, `char_agus`) in Blender Cycles (`256×256`, warm 3-point rim studio lighting, clean soft circular background plate) -> export PNGs to `godot/assets/portraits/portrait_<id>.png` (plus `portrait_ibu_kampung.png` & `portrait_player_cepol.png` / `portrait_player_hijab.png`).
   - Render crisp `128×128` anti-aliased RGBA UI icons & emblems via PIL/NumPy into `godot/assets/ui/`:
     - Bottom dock icons: `icon_phone.png`, `icon_door.png`, `icon_broom.png`, `icon_career.png`, `icon_wardrobe.png`, `icon_upgrade.png`.
     - Smartphone OS app icons: `app_bank.png`, `app_shop.png`, `app_chat.png`, `app_debt.png`, `app_dreams.png`, `app_story.png`, `app_missions.png`, `app_map.png`, `app_guide.png`.
     - HUD & branding assets: `logo_art_simulator.png`, `star_filled.png`, `star_empty.png`, `icon_hand_pointer.png`, `icon_courier_box.png`.
2. **`godot/src/core/portraits.gd`:**
   - Update `get_portrait(speaker_id, mood)` and `get_player_portrait(...)` to load crisp pre-rendered `res://assets/portraits/portrait_<id>.png` textures cleanly (with cached procedural fallback only if an ID is unmapped), and expose `get_ui_icon(icon_name)` loading `res://assets/ui/<icon_name>.png`.

## Phase 3 — 3D Street & Interior Prop Richness
1. **`godot/blender/build_kampung_street.py`:**
   - Replace the duplicate 5th house at `x = +7.60` with an authentic **Indonesian *Musholla* corner** (emerald dome + gold crescent finial, green-and-cream arched portal, warm porch lantern, potted palms).
   - Sharpen `KanstinBlock` black-and-white curb contrast, add a **white Zebra Crossing** across the asphalt (`x = 1.6..3.2`), and add a **parked courier pickup van** (`PickupKurir`) beside the curb.
2. **`godot/blender/build_elite_assets.py` & `build_majikan_interior.py` & `build_kos_room.py`:**
   - Populate `room_elite_living.glb` kitchen island with a woven serving tray, ceramic teapot + mugs, fruit bowl, cutting board, and dual brass pendant lamps overhead; add spice jars, dish rack, and wall clock.
   - Add green `LPG 3kg` gas canister, wall calendar, and kitchenware clutter to `room_majikan_interior.glb` / `kos_room.glb`.
   - Re-run Blender on modified stage `.glb`s (`UV2` lightmaps + JPEG `88`) and re-import in Godot.
3. **`godot/src/core/npc_roster.gd`:** Ensure `anak_sekolah` (`char_pelajar`) and `pak_rt` (`char_pak_rt`) appear on neighborhood sidewalks across street tiers.

## Phase 4 — Title Screen, Frameless Top HUD, Illustrated Dock, Dialogue Cutscene, Smartphone OS & Interactive Spotlight
1. **Title Screen & Seasonal Character Select (`main_game.gd`):**
   - Add Title Screen overlay over the live warmly-lit 3D stage (`logo_art_simulator.png`, `Mulai Baru`, `Lanjutkan / Muat Save` 3-slot picker, `Pengaturan`, `Info Terbaru` changelog modal).
   - Enhance Character Creator with `Musim 1: Karier ART` (active) & `Musim 2: Segera Hadir` card framing + `Kembali`.
2. **Frameless Top HUD & Expandable Task Dropdown:**
   - Replace heavy boxed `_tl_card` & `_tr_vbox` card borders with crisp frameless drop-shadowed typography (`06.00 / SENIN, HARI 1`, `star_filled`/`star_empty` 5-star reputation row, sleek `ENERGI` & `SEMANGAT` bars, bold lime `Rp`, and expandable `TUGAS ▼` dropdown showing sub-task counts, rewards, and `"Cara:"` hints).
   - Soften virtual joystick ring styling and keep lower-left clean for the persistent async courier countdown bar.
3. **Illustrated Bottom Action Dock:**
   - Replace plain text buttons (`Keluar Kamar`, `Mulai Shift`, `Karier`, `Seragam`, `Upgrade Kamar`, `HP`) with crisp **icon + label + circular red unread badge** dock buttons (`60×60` illustrated icon over clean label, zero heavy dark boxes).
4. **Full-Width Bottom Narrative Dialogue Bar + Phone-Call Cutscene + `Panduan 1/2` Bank Card:**
   - After new-game character creation, play the 3-beat intro cutscene in a sleek full-width dark bottom bar (`Ketuk untuk lanjut ▸`) with a smartphone call portrait (`Ibu di Kampung (telepon)`) followed by `Panduan 1/2` embedding a visual **Bank Desaku** transfer card (`Batas Hari 10 • Rp150.000`).
   - Also route `Majikan` call banners & major story beats cleanly with high-res 3D bust portraits.
5. **Interactive Spotlight + Animated Hand Pointer:**
   - Replace the static top-center tutorial rectangle with a dimmed overlay + gold spotlight border around the target HUD control + bouncing `icon_hand_pointer.png` + tooltip + green `Mengerti` pill button.
6. **Diegetic Smartphone OS (`HP Sari`):**
   - Full vertical smartphone frame (`06:05`, `4G`, `Rp`, `Lv`) with 3×3 colorful app-icon grid (`Bank Desaku`, `Belanja`, `Pesan`, `Buku Catatan`, `Impian ART`, `Buku Cerita`, `Misi & Streak`, `Peta`, `Panduan`), `Kembali | Beranda | Tutup HP` nav bar, **"Sisa uang setelah beli: Rp..."** confirmation modal before purchases, and async courier delivery toast (`"Menunggu kurir mengantar... 16 detik"`).

## Phase 5 — Final Verification, Visual Audit, Stage 4 Review & Live Deploy
1. Full `run_tests.gd` (Sections 1–39+) + `--smoke-test` + `npx vitest run`.
2. Capture `gl_compatibility` screenshots of Title Screen, Character Select, Intro Cutscene + Phone Frame, `Panduan 1/2`, Spotlight Tutorial, Smartphone OS, Kampung Street (*Musholla* + Zebra Crossing), and Cluster Elite Kitchen Island -> inspect every screenshot via `vision_analyze`.
3. Stage 4 adversarial pre-commit review (`delegate_task`) -> `./scripts/export_web.sh` + `./scripts/export_android.sh` -> commit, push `main`, Coolify deploy, verify live on `https://game.shr.co.id`.
