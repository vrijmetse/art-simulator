class_name ArtMajikanCall
extends RefCounted

const Profiles := preload("res://src/core/majikan_profiles.gd")

const ACTIVITIES := {
	"working": {"mood_delta": 0, "reaction_delay_s": 0.0, "label_id": "sedang beres-beres", "label_en": "tidying up"},
	"resting": {"mood_delta": 6, "reaction_delay_s": 0.0, "label_id": "istirahat sebentar", "label_en": "taking a quick rest"},
	"playing_game": {"mood_delta": 14, "reaction_delay_s": 2.0, "label_id": "main game di HP", "label_en": "playing on your phone"},
	"calling_boyfriend": {"mood_delta": 18, "reaction_delay_s": 2.5, "label_id": "teleponan sama pacar", "label_en": "chatting on the phone"},
}

static func create_state(profile: Dictionary) -> Dictionary:
	return {
		"profile_id": String(profile.get("id", "ibu_kos_melati")),
		"personality": String(profile.get("personality", "ramah")),
		"base_pay_rp": int(profile.get("base_pay_rp", 35000)),
		"trust": clampi(int(profile.get("initial_trust", 60)), 0, 100),
		"fire_threshold": int(profile.get("fire_threshold", 20)),
		"mood": 50,
		"activity": "working",
		"active_call": false,
		"call_reason": "",
		"call_elapsed_s": 0.0,
		"warnings": 0,
		"tip_bonus_rp": 0,
		"pay_deduction_rp": 0,
		"last_warning_text": "",
		"last_warning_text_en": "",
		"fired": false,
	}

static func apply_distraction(state: Dictionary, activity_id: String) -> Dictionary:
	var nxt: Dictionary = state.duplicate(true)
	if nxt.get("fired", false) or not ACTIVITIES.has(activity_id):
		return nxt
	var act: Dictionary = ACTIVITIES[activity_id]
	nxt["activity"] = activity_id
	nxt["mood"] = clampi(int(nxt["mood"]) + int(act["mood_delta"]), 0, 100)
	return nxt

static func start_call(state: Dictionary, reason: String) -> Dictionary:
	var nxt: Dictionary = state.duplicate(true)
	if nxt.get("active_call", false) or nxt.get("fired", false):
		return nxt
	var act_cfg: Dictionary = ACTIVITIES.get(String(nxt.get("activity", "working")), ACTIVITIES["working"])
	nxt["active_call"] = true
	nxt["call_reason"] = reason
	nxt["call_elapsed_s"] = float(act_cfg["reaction_delay_s"])
	return nxt

static func respond_to_call(state: Dictionary) -> Dictionary:
	var nxt: Dictionary = state.duplicate(true)
	if not nxt.get("active_call", false) or nxt.get("fired", false):
		return nxt
	var pers: Dictionary = Profiles.get_personality(String(nxt.get("personality", "ramah")))
	var patience: float = float(pers["call_patience_s"])
	nxt["active_call"] = false
	if float(nxt["call_elapsed_s"]) <= patience:
		nxt["trust"] = clampi(int(nxt["trust"]) + 6, 0, 100)
		nxt["tip_bonus_rp"] = int(nxt["tip_bonus_rp"]) + 5000
		nxt["activity"] = "working"
		return nxt
	return _apply_miss_penalty(nxt, pers)

static func tick_call(state: Dictionary, dt: float) -> Dictionary:
	var nxt: Dictionary = state.duplicate(true)
	if not nxt.get("active_call", false) or nxt.get("fired", false):
		return nxt
	var clamped_dt: float = clampf(dt, 0.0, 2.0)
	nxt["call_elapsed_s"] = float(nxt["call_elapsed_s"]) + clamped_dt
	var pers: Dictionary = Profiles.get_personality(String(nxt.get("personality", "ramah")))
	if float(nxt["call_elapsed_s"]) > float(pers["call_patience_s"]):
		nxt["active_call"] = false
		return _apply_miss_penalty(nxt, pers)
	return nxt

static func _apply_miss_penalty(nxt: Dictionary, pers: Dictionary) -> Dictionary:
	var act_cfg: Dictionary = ACTIVITIES.get(String(nxt.get("activity", "working")), ACTIVITIES["working"])
	var act_label: String = String(act_cfg["label_id"])
	var act_label_en: String = String(act_cfg.get("label_en", act_label))
	nxt["trust"] = clampi(int(nxt["trust"]) - int(pers["miss_trust_penalty"]), 0, 100)
	nxt["warnings"] = int(nxt["warnings"]) + 1
	nxt["pay_deduction_rp"] = int(nxt["pay_deduction_rp"]) + int(pers["miss_deduction_rp"])
	nxt["last_warning_text"] = String(pers["warning_template"]) % act_label
	nxt["last_warning_text_en"] = String(pers.get("warning_template_en", pers["warning_template"])) % act_label_en
	if int(nxt["trust"]) <= int(nxt["fire_threshold"]) or int(nxt["warnings"]) >= 3:
		nxt["fired"] = true
	nxt["activity"] = "working"
	return nxt

static func final_payout_rp(state: Dictionary) -> int:
	return maxi(0, int(state.get("base_pay_rp", 0)) + int(state.get("tip_bonus_rp", 0)) - int(state.get("pay_deduction_rp", 0)))

static func start_new_shift(_prev_state: Dictionary, profile: Dictionary) -> Dictionary:
	var nxt: Dictionary = create_state(profile)
	nxt["trust"] = maxi(50, int(profile.get("initial_trust", 60)))
	return nxt
