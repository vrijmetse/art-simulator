class_name ArtSettings
extends RefCounted

const MAX_DAILY_LOG := 12

static func sanitize_gfx_quality(val: Variant) -> String:
	return "low" if String(val) == "low" else "high"

static func sanitize_daily_log(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item in (raw as Array):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var entry := {
			"day": maxi(1, int(d.get("day", 1))),
			"kind": String(d.get("kind", "info")).left(24),
			"title_id": String(d.get("title_id", "")).left(80),
			"title_en": String(d.get("title_en", "")).left(80),
			"delta_rp": int(d.get("delta_rp", 0)),
		}
		out.append(entry)
	if out.size() > MAX_DAILY_LOG:
		out = out.slice(out.size() - MAX_DAILY_LOG, out.size())
	return out

static func append_daily_log(save: Dictionary, entry: Dictionary) -> Dictionary:
	var nxt := save.duplicate(true)
	var log_arr: Array = sanitize_daily_log(nxt.get("daily_log", []))
	var clean_entry := {
		"day": maxi(1, int(entry.get("day", nxt.get("day", 1)))),
		"kind": String(entry.get("kind", "info")).left(24),
		"title_id": String(entry.get("title_id", "")).left(80),
		"title_en": String(entry.get("title_en", "")).left(80),
		"delta_rp": int(entry.get("delta_rp", 0)),
	}
	log_arr.append(clean_entry)
	if log_arr.size() > MAX_DAILY_LOG:
		log_arr = log_arr.slice(log_arr.size() - MAX_DAILY_LOG, log_arr.size())
	nxt["daily_log"] = log_arr
	return nxt

static func get_daily_log(save: Dictionary) -> Array:
	return sanitize_daily_log(save.get("daily_log", []))

static func apply_graphics_quality(sun: DirectionalLight3D, env: Environment, quality: String) -> void:
	var is_low := (sanitize_gfx_quality(quality) == "low")
	var is_compat := (RenderingServer.get_current_rendering_method() == "gl_compatibility")
	if sun != null:
		sun.shadow_enabled = not is_low
	if env != null:
		env.ssao_enabled = (not is_low) and (not is_compat)
