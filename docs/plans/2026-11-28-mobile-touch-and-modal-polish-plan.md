# ART Simulator — Mobile Touch UX, `[E]` Removal & Modal/Story/Icon Polish Plan

## Objective
1. Eliminate desktop-only `[E]` keyboard prompts on mobile/touch viewports and make the floating world action prompt directly tappable (`>= 44px`).
2. Fix remaining UX/visual gaps across modals, buttons, text areas, story screens, and portrait/icon polish.

## Changes

### 1. Touch-First Prompts & Tappable World Action (`atmosphere.gd`, `wishlist_story.gd`, `main_game.gd`)
- Add `Atmosphere.should_show_keyboard_hints(viewport_size, is_touch, is_mobile) -> bool`:
  - Returns `false` whenever `is_mobile or viewport_size.x <= 960.0 or (is_touch and viewport_size.x <= 1024.0)`.
- Add `Atmosphere.format_action_prompt(label: String, locale: String, show_key_hint: bool) -> String`:
  - When `show_key_hint`: `"[E] " + label`
  - When touch/mobile: `("Ketuk: " if locale == "id" else "Tap: ") + label` (never `[E]`).
- Add `Atmosphere.format_tasks_hint(locale: String, show_key_hint: bool) -> String`:
  - When `show_key_hint`: `"Cara: dekati lingkaran hijau & tekan [E]"` / `"How: walk to green ring & press [E]"`
  - When touch/mobile: `"Cara: dekati lingkaran hijau lalu ketuk aksi"` / `"How: walk to green ring & tap action"`.
- Update `WishlistStory.get_tutorial_hint(step, locale = "id", show_key_hint: bool = true)`:
  - Backward-compatible 3rd optional param `show_key_hint`; when `false`, Step 3/4 reads `"Langkah 3/4: Dekati lingkaran hijau & ketuk aksi."` / `"Step 3/4: Walk to a green circle & tap action."` (zero `[E]`).
- Replace `_world_prompt` (`PanelContainer` + `Label` with `MOUSE_FILTER_IGNORE`) with a real **`Button`** (`custom_minimum_size.y >= 44`, `mouse_filter = MOUSE_FILTER_STOP`) connected directly to `_trigger_world_action()`, styled as a high-contrast emerald pill with gold border so tapping the floating prompt works on mobile AND desktop mouse!

### 2. Modal / Button / Text Wrapping & Responsive Sizing (`progression.gd`, `main_game.gd`)
- Add `Progression.get_color_label(hex: String, locale: String) -> String` for friendly color names (`"Hijau Batik"`/`"Batik Sage"`, `"Koral"`, `"Biru Denim"`, `"Marun"`, `"Merah Muda"`, `"Krem"`, `"Biru Tua"`, etc.) — replace raw `#4E7D63` hex codes in `_open_wardrobe_modal()`!
- Upgrade `_style_btn(btn, bg, border, txt)`:
  - Always enforce `btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` and `btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 44.0)` so no modal or phone button ever clips text or drops below `44px` touch target.
- In `_show_modal()`:
  - Auto-apply `_style_btn` defaults to any unstyled `Button` inside `_modal_list` (unless already overridden with custom theme `StyleBox`) so Career, Wishlist, Kos Upgrades, Storybook, Settings, Low Energy, and Map district buttons have cohesive dark-slate/gold styling + `autowrap_mode` + `>= 44px` height instead of Godot's default grey box.
  - Size `_modal_card` & `_modal_scroll` responsively from `_effective_window_size()` so modals fit cleanly inside both `1280x720` and `780x437` mobile without vertical or horizontal overflow.

### 3. Story Area, Text Readability & Portrait Distinction (`main_game.gd`, `render_portraits_and_icons.py`)
- Upgrade `_open_chapter_modal(ch)`: wrap body & milestone quote inside styled story parchment/obsidian quote cards with `72x72` gold-framed portrait + generous `AUTOWRAP_WORD_SMART` without hardcoded narrow `360px` width.
- Upgrade `_open_storybook_modal()`: show chapter number badge + short excerpt/status on crisp wrapped cards, plus `"Semua Bab Cerita"` header summary.
- Upgrade `_open_rent_modal()` & `_open_summary_modal()` & `_open_levelup_modal()`: enforce `AUTOWRAP_WORD_SMART` and `SIZE_EXPAND_FILL` on all quote/info labels so English & Indonesian strings never overflow.
- Differentiate `player.png` vs `player_cepol.png` in `render_portraits_and_icons.py` (`player` uses `-14°` yaw + warm apron pocket tint vs `player_cepol` `+16°` yaw + hair highlight) so zero portrait pairs are clones.

## Verification
1. Stage 2 Adversarial Plan Review (`delegate_task`).
2. Strict RED-GREEN-Refactor TDD: Section 40 in `godot/tests/run_tests.gd`.
3. `godot4 --script res://tests/run_tests.gd`, `--smoke-test`, `npx vitest run`.
4. `xvfb-run` `780x437` mobile shift capture (confirming zero `[E]`, tappable prompt, wrapped tasks/buttons) + storybook/modal captures inspected via `vision_analyze`.
5. Stage 4 review, Web + Android export (`index.pck <= 95 MB`), push `main`, Coolify deploy, live Chromium WebGL2 verification.
