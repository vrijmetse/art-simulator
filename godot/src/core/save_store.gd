class_name ArtSaveStore
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")
const Progression := preload("res://src/core/progression.gd")
const SettingsStore := preload("res://src/core/settings_store.gd")
const WishlistStory := preload("res://src/core/wishlist_story.gd")
const Retention := preload("res://src/core/retention.gd")

const DEFAULT_PATH := "user://save_v1.json"

static func _safe_int(val: Variant, fallback: int, min_val: int = 0) -> int:
	var t := typeof(val)
	if t == TYPE_INT:
		return maxi(min_val, int(val))
	if t == TYPE_FLOAT:
		var f := float(val)
		if is_finite(f):
			return maxi(min_val, int(f))
	return fallback

static func sanitize(raw: Variant) -> Dictionary:
	var clean := Progression.create_player_save()
	if typeof(raw) != TYPE_DICTIONARY:
		return clean
	var d: Dictionary = raw

	clean["day"] = _safe_int(d.get("day", 1), 1, 1)
	clean["balance_rp"] = _safe_int(d.get("balance_rp", 0), 0, 0)
	clean["xp"] = _safe_int(d.get("xp", 0), 0, 0)
	clean["completed_shifts"] = _safe_int(d.get("completed_shifts", 0), 0, 0)
	clean["fired_count"] = _safe_int(d.get("fired_count", 0), 0, 0)
	clean["total_earnings_rp"] = _safe_int(d.get("total_earnings_rp", 0), 0, 0)

	var loc := String(d.get("locale", "id"))
	clean["locale"] = "en" if loc == "en" else "id"

	clean["onboarding_done"] = bool(d.get("onboarding_done", false))
	var raw_name := String(d.get("player_name", "Mbak Sari")).strip_edges().left(24)
	clean["player_name"] = "Mbak Sari" if raw_name.is_empty() else raw_name
	var raw_style := String(d.get("starter_style", "cepol"))
	clean["starter_style"] = "hijab" if raw_style == "hijab" else "cepol"
	var raw_skin := String(d.get("skin_hex", "#C68B59"))
	clean["skin_hex"] = raw_skin if Color.html_is_valid(raw_skin) else "#C68B59"
	clean["last_rent_day"] = _safe_int(d.get("last_rent_day", 0), 0, 0)
	clean["pending_rent_rp"] = _safe_int(d.get("pending_rent_rp", 0), 0, 0)
	clean["mood"] = clampi(_safe_int(d.get("mood", 65), 65, 0), 0, 100)
	var clean_chatted := {}
	var raw_chatted: Variant = d.get("chatted_dates", {})
	if typeof(raw_chatted) == TYPE_DICTIONARY:
		for raw_ck in (raw_chatted as Dictionary).keys():
			var ck := String(raw_ck)
			var cv: Variant = (raw_chatted as Dictionary)[raw_ck]
			if typeof(cv) == TYPE_STRING and not ck.is_empty():
				clean_chatted[ck] = String(cv).left(32)
	clean["chatted_dates"] = clean_chatted

	var xp := int(clean["xp"])
	var req_tier := String(d.get("active_tier_id", "kamar_kos"))
	if CareerTiers.can_access_tier(req_tier, xp):
		var sel := Progression.select_job_tier(clean, req_tier)
		clean = sel["save"]
	else:
		var fallback_tier := CareerTiers.get_active_tier(0)
		clean["active_tier_id"] = String(fallback_tier["id"])

	var req_outfit := String(d.get("equipped_outfit_id", "starter_kasual"))
	if CareerTiers.can_equip_outfit(req_outfit, xp):
		clean["equipped_outfit_id"] = req_outfit
	else:
		clean["equipped_outfit_id"] = "starter_kasual"

	var req_color := String(d.get("outfit_color_hex", "#4E7D63"))
	clean["outfit_color_hex"] = req_color if Color.html_is_valid(req_color) else "#4E7D63"

	var valid_ups: Array = []
	var raw_ups: Variant = d.get("unlocked_kos_upgrades", [])
	if typeof(raw_ups) == TYPE_ARRAY:
		for uid in raw_ups:
			var s_uid := String(uid)
			if Progression.KOS_UPGRADES.has(s_uid) and not (s_uid in valid_ups):
				valid_ups.append(s_uid)
	clean["unlocked_kos_upgrades"] = valid_ups

	var clean_sk: Dictionary = clean["skill_xp"]
	var raw_sk: Variant = d.get("skill_xp", {})
	if typeof(raw_sk) == TYPE_DICTIONARY:
		for k in Progression.SKILL_KEYS:
			clean_sk[k] = _safe_int(raw_sk.get(k, 0), 0, 0)
	clean["skill_xp"] = clean_sk

	clean["gfx_quality"] = SettingsStore.sanitize_gfx_quality(d.get("gfx_quality", "high"))
	clean["weather_fx"] = bool(d.get("weather_fx", true))
	clean["muted"] = bool(d.get("muted", false))
	clean["bgm_enabled"] = bool(d.get("bgm_enabled", true))

	var valid_wish: Array = []
	var raw_wish: Variant = d.get("unlocked_wishlist", [])
	if typeof(raw_wish) == TYPE_ARRAY:
		for wid in raw_wish:
			var s_wid := String(wid)
			if WishlistStory.WISHLIST_ITEMS.has(s_wid) and not (s_wid in valid_wish):
				valid_wish.append(s_wid)
	clean["unlocked_wishlist"] = valid_wish

	var valid_ch_ids := {}
	for tid in WishlistStory.STORY_CHAPTERS.keys():
		valid_ch_ids[String(WishlistStory.STORY_CHAPTERS[tid]["id"])] = true
	valid_ch_ids[String(WishlistStory.STORY_EPILOGUE["id"])] = true
	var valid_seen: Array = []
	var raw_seen: Variant = d.get("seen_chapters", [])
	if typeof(raw_seen) == TYPE_ARRAY:
		for ch_id in raw_seen:
			var s_ch := String(ch_id)
			if valid_ch_ids.has(s_ch) and not (s_ch in valid_seen):
				valid_seen.append(s_ch)
	clean["seen_chapters"] = valid_seen

	if d.has("tutorial_step"):
		clean["tutorial_step"] = clampi(_safe_int(d.get("tutorial_step", 0), 0, 0), 0, 4)
	elif int(clean["completed_shifts"]) > 0:
		clean["tutorial_step"] = 4
	else:
		clean["tutorial_step"] = 0

	clean["login_streak"] = clampi(_safe_int(d.get("login_streak", 0), 0, 0), 0, 7)
	clean["last_login_date"] = String(d.get("last_login_date", "")).left(16)
	clean["streak_claimed_date"] = String(d.get("streak_claimed_date", "")).left(16)
	var raw_dm: Variant = d.get("daily_missions", {})
	if typeof(raw_dm) == TYPE_DICTIONARY:
		var dm_d: Dictionary = raw_dm
		var clean_prog := {}
		var raw_p: Variant = dm_d.get("progress", {})
		if typeof(raw_p) == TYPE_DICTIONARY:
			for k in (raw_p as Dictionary).keys():
				clean_prog[String(k)] = maxi(0, _safe_int((raw_p as Dictionary)[k], 0, 0))
		var clean_cl: Array = []
		var raw_cl: Variant = dm_d.get("claimed", [])
		if typeof(raw_cl) == TYPE_ARRAY:
			for cid in raw_cl:
				var sc := String(cid)
				if not (sc in clean_cl):
					clean_cl.append(sc)
		clean["daily_missions"] = {"date": String(dm_d.get("date", "")).left(16), "progress": clean_prog, "claimed": clean_cl}
	else:
		clean["daily_missions"] = {}

	var valid_badges: Array = []
	var raw_bd: Variant = d.get("unlocked_badges", [])
	if typeof(raw_bd) == TYPE_ARRAY:
		for bid in raw_bd:
			var s_bid := String(bid)
			if Retention.BADGES.has(s_bid) and not (s_bid in valid_badges):
				valid_badges.append(s_bid)
	clean["unlocked_badges"] = valid_badges
	clean["shift_boost_count"] = _safe_int(d.get("shift_boost_count", 0), 0, 0)
	clean["calls_answered_count"] = _safe_int(d.get("calls_answered_count", 0), 0, 0)

	clean["daily_log"] = SettingsStore.sanitize_daily_log(d.get("daily_log", []))

	return clean

static func serialize(save: Dictionary) -> String:
	return JSON.stringify(sanitize(save))

static func deserialize(json_text: String) -> Dictionary:
	if json_text.strip_edges().is_empty():
		return Progression.create_player_save()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return Progression.create_player_save()
	return sanitize(json.data)

static func save_to_path(save: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var text := serialize(save)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return true

static func load_from_path(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return Progression.create_player_save()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Progression.create_player_save()
	var text := f.get_as_text()
	f.close()
	return deserialize(text)
