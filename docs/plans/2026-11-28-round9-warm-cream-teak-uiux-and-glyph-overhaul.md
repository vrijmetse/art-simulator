# Round 9 — Warm Cream & Teak Cozy UI/UX + Zero-Tofu Glyph Overhaul

**Date:** 2026-11-28
**Goal:** Replace the dark-navy/neon-yellow form-style modals and broken emoji glyphs with the studio-grade **Variant A: Warm Cream & Teak Cozy** design system across **every modal, card grid, HUD bar, and label** — verified on both `780×437` landscape and `390×844` portrait.

## Scope & Architecture

### 1. Zero-Tofu Font Safety (`godot/src/scenes/main_game.gd`)
- Remove ALL glyphs unsupported by `DejaVuSans.ttf` (`📷`, `📸`, `🌏`, `📖`, `🔒`, `✨`, `🏅`, `📍`, `📞`, `🌧`, `🌙`).
- Replace with `DejaVuSans`-verified glyphs (`★`, `☆`, `✓`, `×`, `•`, `●`, `⚡`, `☀`, `▼`, `▲`) and crisp text/icon badges (`Foto`, `Telp`, `Hujan`, `Malam`, `Terkunci`).

### 2. Warm Cream & Teak Modal Shell (`_modal_card`, `_clear_modal`, `_show_modal`, `_auto_style_modal_buttons`, `_add_modal_section`)
- **Card Surface:** `#FFF8EE` parchment (`Color(1.0, 0.973, 0.933, 0.99)`), `2.5px` warm teak border `#C69C6D`, `18px` rounded corners.
- **Header Row:** Left-aligned bold espresso title (`#2D2118`) + top-right circular `×` Close button (`_btn_modal_close`, `44×44` touch target, `#EFE2D1` fill, `#5C4330` ink) — eliminates both the giant yellow header pill AND the 60px yellow `Tutup` footer bar!
- **Contrast-Safe Light Surfaces:** Update all modal labels, section headers (`#8A521E`), chapter/story/log/dilemma/cultural-note cards (`#FFFFFF` with `#E5D4BE` border and `#2D2118` espresso text), and `_auto_style_modal_buttons()` (`#FFFFFF` / `#2D7A53` / `#EFE3D2` disabled) so every single modal maintains `>= 4.5:1` contrast (zero white-on-cream invisible text!).
- **Non-Dismissible Back Guard:** Update `NOTIFICATION_WM_GO_BACK_REQUEST` to respect `not _btn_modal_close.visible` so mandatory Rent/Dilemma modals cannot be dismissed via Android Back.

### 3. Segmented Tabs + 2-Column Cozy Icon Cards (`_open_kos_modal`, `_open_wishlist_modal`)
- `_open_kos_modal(tab: String = "facilities")`:
  - Top wallet + max-energy summary pills (`#E4F4E7` / `#F5E8D3`).
  - Segmented pill tabs: `Fasilitas Kamar` (`facilities`) | `Dekorasi` (`decor`).
  - Responsive `GridContainer` (`2` columns when `canvas_sz.x >= 680`, `1` column on portrait) of cozy white cards with illustrated PNG icon badge (`Portraits.get_ui_icon`), bold title, stat pill (`+10 Energi`, `+5% Tip`), and clean CTA (`Rp 45.000` / `✓ Terpasang` / `Geser Spot` + `Putar 45°`).
- `_open_wishlist_modal(tab: String = "dreams")`:
  - Segmented tabs (`Impian ART` | `Agensi & Usaha` when epilogue unlocked) + 2-column cozy icon cards.

### 4. Cohesive Warm Espresso-Glass HUD & Photo Pill (`_build_hud`, `_build_onboarding_overlay`, `_build_title_overlay`)
- Unify HUD glass panels (`_tl_card`, `bal_pill`, `dock_scrim`, `_toast_panel`, `_tasks_card`) to warm espresso glass (`Color(0.14, 0.10, 0.08, 0.84)`) with soft teak-amber borders (`Color(0.84, 0.66, 0.44, 0.72)`), and replace `📷` on `_btn_photo` with clean `Foto` / `Photo` pill (`68×44`).

## TDD Plan (Stage 3 Red → Green)
Add **Section 49** in `godot/tests/run_tests.gd`:
1. Assert zero unsupported tofu emojis (`📷`, `📸`, `🌏`, `📖`, `🔒`, `✨`, `🏅`, `📍`, `📞`, `🌧`, `🌙`) remain in `godot/src/scenes/main_game.gd` and `godot/src/core/`.
2. Assert `_modal_card` uses Warm Cream `#FFF8EE` / Teak `#C69C6D` palette, `_btn_modal_close` uses compact `×` in the header row, `_open_kos_modal` and `_open_wishlist_modal` support segmented `tab` switching (`facilities`/`decor`, `dreams`/`agency`), and `NOTIFICATION_WM_GO_BACK_REQUEST` guards `_btn_modal_close.visible`.
3. Compile check (`load("res://src/scenes/main_game.gd") != null`), headless `-- --smoke-test`, `48/48` Vitest, and visual screenshot verification across Kos Modal (Facilities & Decor tabs), Dreams/Agency Modal, Career, Cultural Notes, Dilemma, Summary, and `390×844` Portrait!
