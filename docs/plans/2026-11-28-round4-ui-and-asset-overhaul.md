# Round 4 — Comprehensive Asset, Portrait & UI/Modal Polish Plan

**Goal:** Resolve every Critical, Important, and visual-quality defect found in the Round 4 adversarial UI & Asset audit across all 20 UI icons, 20 character portraits, modals, Title/Onboarding, and Smartphone OS (`780x437` mobile landscape + `1280x720` desktop).

---

## Scope & Exact File Changes

### 1. Core Formatting & Copy Fixes (`godot/src/core/wishlist_story.gd`, `godot/src/scenes/main_game.gd`)
- **`godot/src/core/wishlist_story.gd` (`get_onboarding_guides`, lines 368-415):**
  - Replace raw `"Rp%d"` with `I18n.format_balance(...)` (or preload `i18n.gd` as `I18n` helper) so Guide 1 displays `"Rp 250.000"` and `"Terkirim Rp 0 dari Rp 150.000"` (`"Sent Rp 0 of Rp 150.000"`).
  - Replace raw ASCII `"->"` with `"→"` in guide body copy.
- **`godot/src/scenes/main_game.gd`:**
  - **Fix `_show_modal()` canvas sizing (lines 1771-1783):** Use `var canvas_sz := get_viewport().get_visible_rect().size` (in `canvas_items` stretch space, `~1280x720` / `1285x720`), sizing `_modal_card` to `Vector2(minf(780.0, canvas_sz.x - 100.0), minf(560.0, canvas_sz.y - 72.0))` and `_modal_scroll` to `Vector2(minf(736.0, canvas_sz.x - 144.0), minf(420.0, canvas_sz.y - 210.0))` so bottom rows in Career, Wardrobe, Kos Upgrades, Map, Wishlist, Storybook, Settings, and Rent never clip behind a 240px box.
  - **Fix `_btn_modal_close` copy & Guide dual-CTA (lines 1749, 1802, 3475-3525):**
    - Set `_btn_modal_close.text = _t("Tutup", "Close")` instead of `"Mantap!"`.
    - In `_clear_modal()`, restore `_btn_modal_close.visible = true`.
    - In `_open_guide_modal()`, hide `_btn_modal_close` when `guide_idx == 0` (or both guide pages since `next_b` is the single explicit `"Lanjut (2/2)"` / `"Mengerti, Mulai!"` CTA).
  - **Fix Save Slots blank red button & row height (`_open_save_slots_modal`, lines 3316-3367):**
    - Set `del_b.custom_minimum_size = Vector2(96, 44)` and `del_b.set_meta("skip_autowrap", true)` so `_auto_style_modal_buttons()` does not wrap/crush `"Hapus"` / `"Yakin Hapus?"` to 0px width.
    - Check `not b.has_meta("skip_autowrap")` inside `_auto_style_modal_buttons()`.
  - **Fix Missions duplicate prefix & contrast (`_open_retention_modal`, lines 1883-1947):**
    - Strip duplicate `"Hari %d: "` / `"Day %d: "` prefix from `rw_lbl` before formatting `"★ Klaim Streak Hari %d: %s ..."`, and style disabled mission buttons cleanly (`Color(0.14, 0.17, 0.23, 0.92)` with crisp `Color(0.90, 0.90, 0.88)` text instead of low-contrast Godot grey).
  - **Fix Wallet context & iconography in modals (`career`, `kos_upgrade`, `wishlist`, `settings`):**
    - Show current balance (`Saldo Dompet: Rp ...`) at the top of `kos_upgrade` and `wishlist` modals so players know affordability without closing.
    - Add `22x22` `TextureRect` icons on `settings` modal rows (`icon_career`, `icon_wardrobe`, `icon_door`, `app_dreams`, `app_missions`) for visual hierarchy.
    - Add subtle dark translucent pill behind Title screen `ver_lbl` (`Versi 1.5 (HD)`) and ensure `_title_btn_news` + onboarding swatches are `>= 44px` tall.
  - **Fix Phone OS landscape sizing, borders, `chat`, and `debt` (`_build_phone_os`, `_render_phone_app`, lines 3814-4062):**
    - Scale `_phone_os_bezel` & `sc` (`ScrollContainer`) in `canvas_sz` (`get_viewport().get_visible_rect().size`) when `is_land` (`Vector2(860, 560)` bezel / `Vector2(812, 415)` scroll) vs portrait (`Vector2(380, 500)`).
    - Use consistent gold-accented border across all 3 Phone OS bottom-nav buttons (`Kembali`, `Beranda`, `Tutup HP`).
    - Add proper `PanelContainer` header cards to **`phone_chat`** (`Pesan & Aktivitas HP` / `Messages & Activities`) and **`phone_shop`** / **`phone_debt`**, change `(+Mood)` in Indonesian `chat` to `(+Semangat)` + concise description, and format **`phone_debt`** `25000` via `I18n.format_balance(25000, _loc())` (`Rp 25.000`).

### 2. 3D UI Icons & Emblem Re-Render (`godot/blender/render_3d_ui_assets.py`)
- **`app_story.png`**: Redesign as a clear **Open Hardcover Book** (warm leather cover base behind angled cream pages + crisp center gutter line + red/gold bookmark ribbon protruding at bottom) so it reads unmistakably as a storybook.
- **`app_shop.png`**: Redesign as a **rounded Shopping Tote / Paper Bag with curved Torus handles** + emerald leaf + warm orange bottle peeking from the top.
- **`icon_wardrobe.png`**: Redesign as a **two-door cozy wooden Wardrobe / Lemari with brass handles** (one door slightly ajar showing teal/batik cloth inside) so it reads unmistakably as Wardrobe.
- **`app_debt.png`**: Redesign as a **ruled Ledger Book with spiral spine rings and a raised golden `Rp` coin disc** on the front.
- **`icon_hand_pointer.png`**: Refine proportions (shorter, rounded cartoon white-gloved tapping hand with subtle gold tap ring beneath the index tip).
- **`star_filled.png`**: Rich vibrant warm gold (`(1.0, 0.78, 0.08)`, stronger contrast/bevel) vs cool slate `star_empty.png`.
- **`logo_art_simulator.png`**: Crisp gold contrast + larger `"COZY HOMEKEEPER"` pill text (`0.22` size) for mobile legibility.

### 3. Character Portrait Anti-Clipping & Framing Fixes (`godot/blender/render_portraits_and_icons.py`)
- **`pak_rt`**: Pull portrait camera slightly back (`dist = 0.88`, `target_z + 0.015`) so his peci cap never clips the top frame border.
- **Anti-clipping prop offsets (`_attach_bust_prop`):**
  - Move `glasses` forward (`hy - 0.118`) and slightly wider (`sx = ±0.038`) so frames never intersect nose bridges.
  - Replace forehead-floating `sunglasses` discs on `kakak_nadine` with a sleek perched hairband/clip or clean wide-frame shades with bridge.
  - Raise `headband` (`hy + 0.025, hz + 0.072`) and `cap_blue` (`hz + 0.075`) cleanly above bangs so they never slice into hair.
- **Expressive eyes & cast differentiation:** Darken/warm iris materials slightly in portrait renders (`_tint_materials` iris warmth/specular) and vary camera yaw/key angle cleanly so portraits feel lively and distinct.

### 4. Automated TDD & Visual QA Gates (`godot/tests/run_tests.gd`, `scripts/check_assets.py`)
- Add Section 41 TDD to `godot/tests/run_tests.gd`:
  - Assert `WishlistStory.get_onboarding_guides` formats `Rp 250.000` & `Rp 150.000` with space + dots and zero `->` ASCII.
  - Assert `main_game.gd` source uses `"Tutup"` / `"Close"` for `_btn_modal_close`, has `skip_autowrap` guard, and uses `I18n.format_balance` in `phone_debt` (no hardcoded `Rp25.000`).
- Run headless `SubViewport` layout bounds verification (`capture_all_ui.gd`) across **both `780x437` and `1280x720`** (calling `_open_onboarding()` & `_open_phone_os("home")` properly) + PIL raster QA on all 20 UI icons + 20 portraits, then run **3 blind adversarial visual review batches** (`>= 8.5 / 10` bar) before committing & deploying!
