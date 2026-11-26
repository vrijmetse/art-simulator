class_name ArtProgression
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")
const MajikanProfiles := preload("res://src/core/majikan_profiles.gd")
const MajikanCall := preload("res://src/core/majikan_call.gd")

const SKILL_KEYS := ["sweeping", "tidiness", "cooking", "laundry"]
const SKILL_THRESHOLDS := [0, 30, 80, 160, 280]

const KOS_UPGRADES := {
	"kipas_angin": {
		"id": "kipas_angin",
		"cost_rp": 45000,
		"energy_bonus": 10,
		"mood_bonus": 0,
		"tip_bonus_pct": 0.0,
		"label_id": "Kipas Angin Baru (+10 Energi)",
		"label_en": "New Standing Fan (+10 Energy)",
	},
	"rak_sepatu": {
		"id": "rak_sepatu",
		"cost_rp": 65000,
		"energy_bonus": 0,
		"mood_bonus": 4,
		"tip_bonus_pct": 0.05,
		"label_id": "Rak Sepatu Rapi (+5% Tip)",
		"label_en": "Tidy Shoe Rack (+5% Tips)",
	},
	"kasur_empuk": {
		"id": "kasur_empuk",
		"cost_rp": 120000,
		"energy_bonus": 15,
		"mood_bonus": 8,
		"tip_bonus_pct": 0.0,
		"label_id": "Kasur Busa Empuk (+15 Energi)",
		"label_en": "Plush Foam Mattress (+15 Energy)",
	},
	"magic_com_pro": {
		"id": "magic_com_pro",
		"cost_rp": 150000,
		"energy_bonus": 12,
		"mood_bonus": 5,
		"tip_bonus_pct": 0.04,
		"label_id": "Magic Com Hemat (+12 Energi)",
		"label_en": "Eco Rice Cooker (+12 Energy)",
	},
	"ac_hemat": {
		"id": "ac_hemat",
		"cost_rp": 350000,
		"energy_bonus": 25,
		"mood_bonus": 12,
		"tip_bonus_pct": 0.08,
		"label_id": "AC Kamar (+25 Energi)",
		"label_en": "Room AC (+25 Energy)",
	},
}

static func level_from_xp(xp: int) -> int:
	return 1 + int(floor(sqrt(float(maxi(0, xp)) / 40.0)))

static func get_room_upgrade_title(_tier: Dictionary = {}, locale: String = "id") -> String:
	return "Upgrade Room" if locale == "en" else "Upgrade Kamar"

static func trust_to_stars(trust: int) -> String:
	var filled := clampi(int(round(float(trust) / 20.0)), 0, 5)
	return "★".repeat(filled) + "☆".repeat(5 - filled)

static func format_shift_clock(day: int, elapsed_s: float, locale: String = "id") -> String:
	var days_id := ["SENIN", "SELASA", "RABU", "KAMIS", "JUMAT", "SABTU", "MINGGU"]
	var days_en := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
	var d_idx := posmod(maxi(1, day) - 1, 7)
	var day_name: String = days_en[d_idx] if locale == "en" else days_id[d_idx]
	var total_mins := 7 * 60 + 30 + int(floor(maxf(0.0, elapsed_s) * 0.5))
	var hh := (total_mins / 60) % 24
	var mm := total_mins % 60
	var day_prefix := "DAY" if locale == "en" else "HARI"
	return "%02d.%02d  %s, %s %d" % [hh, mm, day_name, day_prefix, maxi(1, day)]

static func skill_level_from_xp(skill_xp: int) -> int:
	var sxp := maxi(0, skill_xp)
	var lvl := 1
	for i in range(SKILL_THRESHOLDS.size()):
		if sxp >= int(SKILL_THRESHOLDS[i]):
			lvl = i + 1
	return lvl

static func create_player_save() -> Dictionary:
	return {
		"version": 1,
		"day": 1,
		"balance_rp": 0,
		"xp": 0,
		"locale": "id",
		"active_tier_id": "kamar_kos",
		"active_profile_id": "ibu_kos_melati",
		"equipped_outfit_id": "starter_kasual",
		"outfit_color_hex": "#4E7D63",
		"unlocked_kos_upgrades": [],
		"skill_xp": {
			"sweeping": 0,
			"tidiness": 0,
			"cooking": 0,
			"laundry": 0,
		},
		"completed_shifts": 0,
		"fired_count": 0,
		"total_earnings_rp": 0,
	}

static func get_max_energy(save: Dictionary) -> int:
	var total := 100
	var ups: Array = save.get("unlocked_kos_upgrades", [])
	for uid in ups:
		if KOS_UPGRADES.has(uid):
			total += int(KOS_UPGRADES[uid]["energy_bonus"])
	return total

static func get_tip_bonus_multiplier(save: Dictionary) -> float:
	var bonus := 1.0
	var ups: Array = save.get("unlocked_kos_upgrades", [])
	for uid in ups:
		if KOS_UPGRADES.has(uid):
			bonus += float(KOS_UPGRADES[uid]["tip_bonus_pct"])
	return bonus

static func buy_kos_upgrade(save: Dictionary, upgrade_id: String) -> Dictionary:
	if not KOS_UPGRADES.has(upgrade_id):
		return {"ok": false, "reason": "unknown_upgrade", "save": save}
	var ups: Array = save.get("unlocked_kos_upgrades", [])
	if upgrade_id in ups:
		return {"ok": false, "reason": "already_owned", "save": save}
	var cost := int(KOS_UPGRADES[upgrade_id]["cost_rp"])
	var bal := int(save.get("balance_rp", 0))
	if bal < cost:
		return {"ok": false, "reason": "insufficient_funds", "save": save}
	var nxt := save.duplicate(true)
	nxt["balance_rp"] = bal - cost
	var nxt_ups: Array = nxt.get("unlocked_kos_upgrades", [])
	nxt_ups.append(upgrade_id)
	nxt["unlocked_kos_upgrades"] = nxt_ups
	return {"ok": true, "reason": "", "save": nxt}

static func equip_outfit(save: Dictionary, outfit_id: String, color_hex: String) -> Dictionary:
	var xp := int(save.get("xp", 0))
	if not CareerTiers.can_equip_outfit(outfit_id, xp):
		return {"ok": false, "reason": "outfit_locked", "save": save}
	if not Color.html_is_valid(color_hex):
		return {"ok": false, "reason": "invalid_color", "save": save}
	var nxt := save.duplicate(true)
	nxt["equipped_outfit_id"] = outfit_id
	nxt["outfit_color_hex"] = color_hex
	return {"ok": true, "reason": "", "save": nxt}

static func select_job_tier(save: Dictionary, tier_id: String) -> Dictionary:
	var xp := int(save.get("xp", 0))
	if not CareerTiers.can_access_tier(tier_id, xp):
		return {"ok": false, "reason": "tier_locked", "save": save}
	var profiles := MajikanProfiles.get_profiles_for_tier(tier_id)
	var prof_id := String(profiles[0]["id"]) if not profiles.is_empty() else "ibu_kos_melati"
	var nxt := save.duplicate(true)
	nxt["active_tier_id"] = tier_id
	nxt["active_profile_id"] = prof_id
	return {"ok": true, "reason": "", "save": nxt}

static func settle_shift(save: Dictionary, shift: Dictionary, call_state: Dictionary) -> Dictionary:
	if bool(shift.get("settled", false)):
		return {"ok": false, "reason": "already_settled", "save": save, "shift": shift, "payout_rp": 0, "xp_gained": 0}

	var is_fired := bool(call_state.get("fired", false))
	var chore_rp := maxi(0, int(shift.get("earned_rp", 0)))
	var contract_rp := 0 if is_fired else MajikanCall.final_payout_rp(call_state)
	var tip_mult := 1.0 if is_fired else get_tip_bonus_multiplier(save)
	var adjusted_contract := int(round(float(contract_rp) * tip_mult))
	var total_payout := maxi(0, chore_rp + adjusted_contract)

	var raw_xp := maxi(0, int(shift.get("xp_earned", 0)))
	var xp_gained := int(floor(float(raw_xp) * 0.5)) if is_fired else raw_xp

	var nxt_save := save.duplicate(true)
	nxt_save["balance_rp"] = int(nxt_save.get("balance_rp", 0)) + total_payout
	nxt_save["total_earnings_rp"] = int(nxt_save.get("total_earnings_rp", 0)) + total_payout
	nxt_save["xp"] = int(nxt_save.get("xp", 0)) + xp_gained
	nxt_save["day"] = int(nxt_save.get("day", 1)) + 1
	nxt_save["completed_shifts"] = int(nxt_save.get("completed_shifts", 0)) + (0 if is_fired else 1)
	nxt_save["fired_count"] = int(nxt_save.get("fired_count", 0)) + (1 if is_fired else 0)

	var sk: Dictionary = nxt_save.get("skill_xp", {})
	var earned_sk: Dictionary = shift.get("skill_xp_earned", {})
	for k in SKILL_KEYS:
		var gain := int(earned_sk.get(k, 0))
		if is_fired:
			gain = int(floor(float(gain) * 0.5))
		sk[k] = int(sk.get(k, 0)) + gain
	nxt_save["skill_xp"] = sk

	var nxt_shift := shift.duplicate(true)
	nxt_shift["settled"] = true

	return {
		"ok": true,
		"reason": "",
		"payout_rp": total_payout,
		"xp_gained": xp_gained,
		"fired": is_fired,
		"save": nxt_save,
		"shift": nxt_shift,
	}
