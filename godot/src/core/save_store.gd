class_name ArtSaveStore
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")
const Progression := preload("res://src/core/progression.gd")

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
