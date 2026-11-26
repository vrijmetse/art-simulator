# Character Growth, Story Epilogue & Level Polish Plan (`2026-11-26`)

## Scope (4 Remaining Polish Items)
1. **XP Progress + Extended Career Ranks (`progression.gd`, `economy.gd`):**
   - `Progression.get_xp_progress(xp: int) -> Dictionary`: returns `{level, current_xp, floor_xp, next_xp, xp_in_level, xp_needed, ratio}` matching `level_from_xp(xp) = 1 + floor(sqrt(xp/40))`.
   - `Economy.get_career_rank(xp, locale)`: extend above `300 XP` (`ART Andalan` / `Master Homekeeper`) with `600 XP` (`ART Profesional` / `Senior Housekeeper`) and `1400 XP` (`Housekeeper Teladan` / `Elite Housekeeper`), preserving `0`, `75`, `150`, `300` tiers cleanly.
   - `Progression.KOS_UPGRADES["kipas_angin"]["mood_bonus"] = 4` (starter room fan improves mood too).
2. **Level-Up Unlocks Summary (`progression.gd`, `main_game.gd`):**
   - `Progression.get_xp_unlocks(prev_xp: int, new_xp: int, locale: String) -> Array` returns localized strings for `+4%` contract tip gain per level, newly unlocked housing tiers (`CareerTiers`), and newly unlocked uniform tiers (`CareerTiers.OUTFIT_TIERS`).
   - Display XP progress bar + Career Rank inside **`Karier`** modal AND display concrete unlocked perks inside **`_open_levelup_modal`** & **`_open_rent_modal(..., leveled_up_to)`**.
3. **Grand Epilogue & Buku Cerita (`wishlist_story.gd`, `save_store.gd`, `main_game.gd`):**
   - `ArtWishlistStory.STORY_EPILOGUE` (`id: "ch_epilogue"`), `is_epilogue_unlocked(save)` (`can_access_tier("cluster_elite", xp)` AND all 4 `WISHLIST_ITEMS` achieved), `get_unseen_epilogue(save)`, `get_storybook_entries(save, locale)`.
   - `SaveStore.sanitize()` adds `"ch_epilogue"` to valid `seen_chapters` IDs.
   - Add **`Buku Cerita`** button in `Karier` & `Menu` opening `_open_storybook_modal()` so players can re-read all unlocked chapters + Epilog; trigger `_open_chapter_modal(epilogue)` cleanly upon completing both prerequisites (Cluster Elite + all 4 Wishlist items), queued behind Shift modals via `_btn_modal_close`.
4. **Compact XP Progress in Top-Left HUD (`main_game.gd`):**
   - Display `Lv %d (%d/%d XP) • %s` cleanly in `_lbl_balance` (or keep crisp without crowding `780x437`).
