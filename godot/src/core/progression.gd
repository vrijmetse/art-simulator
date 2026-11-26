class_name ArtProgression
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")
const MajikanProfiles := preload("res://src/core/majikan_profiles.gd")
const MajikanCall := preload("res://src/core/majikan_call.gd")
const WishlistStory := preload("res://src/core/wishlist_story.gd")

const SKILL_KEYS := ["sweeping", "tidiness", "cooking", "laundry"]
const SKILL_THRESHOLDS := [0, 30, 80, 160, 280]

const KOS_UPGRADES := {
	"kipas_angin": {
		"id": "kipas_angin",
		"cost_rp": 45000,
		"energy_bonus": 10,
		"mood_bonus": 4,
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

static func get_xp_progress(xp: int) -> Dictionary:
	var cur := maxi(0, xp)
	var lv := level_from_xp(cur)
	var floor_xp := 40 * (lv - 1) * (lv - 1)
	var next_xp := 40 * lv * lv
	var in_lv := maxi(0, cur - floor_xp)
	var needed := maxi(1, next_xp - floor_xp)
	return {
		"level": lv,
		"current_xp": cur,
		"floor_xp": floor_xp,
		"next_xp": next_xp,
		"xp_in_level": in_lv,
		"xp_needed": needed,
		"ratio": clampf(float(in_lv) / float(needed), 0.0, 1.0),
	}

static func get_xp_unlocks(prev_xp: int, new_xp: int, locale: String = "id") -> Array:
	var out: Array = []
	var prev_lv := level_from_xp(prev_xp)
	var new_lv := level_from_xp(new_xp)
	if new_lv > prev_lv:
		var total_pct := int(round(get_level_tip_bonus(new_xp) * 100.0))
		out.append(("Contract Bonus +%d%% (+4%%/Lv)" % total_pct) if locale == "en" else ("Bonus Gaji Kontrak +%d%% (+4%%/Lv)" % total_pct))
	for t in CareerTiers.TIERS:
		var tid := String(t["id"])
		if CareerTiers.can_access_tier(tid, new_xp) and not CareerTiers.can_access_tier(tid, prev_xp):
			var h_name := String(t.get("house_type_en", t["house_type"]) if locale == "en" else t["house_type"])
			out.append(("New District Unlocked: %s" % h_name) if locale == "en" else ("Distrik Baru Terbuka: %s" % h_name))
	for o in CareerTiers.OUTFIT_TIERS:
		var oid := String(o["id"])
		if CareerTiers.can_equip_outfit(oid, new_xp) and not CareerTiers.can_equip_outfit(oid, prev_xp):
			var o_name := String(o.get("label_en", o["label_id"]) if locale == "en" else o["label_id"])
			out.append(("New Uniform Unlocked: %s" % o_name) if locale == "en" else ("Seragam Baru Terbuka: %s" % o_name))
	return out

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
		"onboarding_done": false,
		"player_name": "Mbak Sari",
		"starter_style": "cepol",
		"skin_hex": "#C68B59",
		"last_rent_day": 0,
		"pending_rent_rp": 0,
		"mood": 65,
		"chatted_dates": {},
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
		"gfx_quality": "high",
		"weather_fx": true,
		"muted": false,
		"bgm_enabled": true,
		"unlocked_wishlist": [],
		"seen_chapters": [],
		"tutorial_step": 0,
		"daily_log": [],
	}

static func resolve_player_model_path(save: Dictionary) -> String:
	var oid := String(save.get("equipped_outfit_id", "starter_kasual"))
	var style := String(save.get("starter_style", "cepol"))
	if oid == "starter_kasual":
		return "res://assets/models/char_art_hijab.glb" if style == "hijab" else "res://assets/models/char_art.glb"
	for o in CareerTiers.OUTFIT_TIERS:
		if o["id"] == oid:
			return String(o["model_path"])
	return "res://assets/models/char_art.glb"

static func complete_onboarding(save: Dictionary, raw_name: String, starter_style: String, skin_hex: String, outfit_color_hex: String) -> Dictionary:
	var clean_name := raw_name.strip_edges().left(24)
	if clean_name.is_empty():
		clean_name = "Mbak Sari"
	var clean_style := "hijab" if starter_style == "hijab" else "cepol"
	var clean_skin := skin_hex if Color.html_is_valid(skin_hex) else "#C68B59"
	var clean_col := outfit_color_hex if Color.html_is_valid(outfit_color_hex) else "#4E7D63"
	var nxt := save.duplicate(true)
	nxt["onboarding_done"] = true
	nxt["player_name"] = clean_name
	nxt["starter_style"] = clean_style
	nxt["skin_hex"] = clean_skin
	nxt["outfit_color_hex"] = clean_col
	return {"ok": true, "save": nxt}

static func should_collect_weekly_rent(save: Dictionary, tier: Dictionary) -> bool:
	if bool(tier.get("live_in_room_provided", false)):
		return false
	if int(save.get("pending_rent_rp", 0)) > 0:
		return true
	var day := int(save.get("day", 1))
	var last_rent := int(save.get("last_rent_day", 0))
	return day >= 7 and (day - last_rent) >= 7

static func pay_weekly_rent(save: Dictionary, pay_now: bool, rent_rp: int = 120000) -> Dictionary:
	var nxt := save.duplicate(true)
	var day := int(nxt.get("day", 1))
	var bal := int(nxt.get("balance_rp", 0))
	var pending := int(nxt.get("pending_rent_rp", 0))
	var due_rp := pending if pending > 0 else rent_rp
	if pay_now:
		if bal < due_rp:
			return {"ok": false, "reason": "insufficient_funds", "due_rp": due_rp, "save": save}
		nxt["balance_rp"] = bal - due_rp
		nxt["pending_rent_rp"] = 0
		nxt["last_rent_day"] = day
		return {"ok": true, "paid": due_rp, "save": nxt}
	nxt["pending_rent_rp"] = due_rp + 15000
	return {"ok": true, "paid": 0, "late_fee_rp": 15000, "due_rp": int(nxt["pending_rent_rp"]), "save": nxt}

static func get_max_energy(save: Dictionary) -> int:
	var total := 100
	var ups: Array = save.get("unlocked_kos_upgrades", [])
	for uid in ups:
		if KOS_UPGRADES.has(uid):
			total += int(KOS_UPGRADES[uid]["energy_bonus"])
	return total

static func get_mood_bonus(save: Dictionary) -> int:
	var bonus := 0
	var ups: Array = save.get("unlocked_kos_upgrades", [])
	for uid in ups:
		if KOS_UPGRADES.has(uid):
			bonus += int(KOS_UPGRADES[uid].get("mood_bonus", 0))
	bonus += WishlistStory.get_wishlist_mood_bonus(save)
	return bonus

static func get_shift_starting_mood(save: Dictionary) -> int:
	return clampi(int(save.get("mood", 60)) + get_mood_bonus(save), 35, 100)

static func get_level_tip_bonus(xp: int) -> float:
	return minf(0.32, float(maxi(0, level_from_xp(xp) - 1)) * 0.04)

static func get_tip_bonus_multiplier(save: Dictionary) -> float:
	var bonus := 1.0 + get_level_tip_bonus(int(save.get("xp", 0)))
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
	var done_count: int = (shift.get("completed_ids", []) as Array).size()
	var total_count := maxi(1, (shift.get("assigned_ids", []) as Array).size())

	# 0-chore instant-exit guard (only treated as free abort when not fired!)
	if done_count == 0 and not is_fired:
		var aborted_shift := shift.duplicate(true)
		aborted_shift["settled"] = true
		return {
			"ok": true,
			"aborted": true,
			"reason": "no_chores_done",
			"payout_rp": 0,
			"xp_gained": 0,
			"fired": false,
			"save": save.duplicate(true),
			"shift": aborted_shift,
		}

	var chore_rp := maxi(0, int(shift.get("earned_rp", 0)))
	var raw_contract := 0 if is_fired else MajikanCall.final_payout_rp(call_state)
	var completion_ratio := clampf(float(done_count) / float(total_count), 0.0, 1.0)
	var prorated_contract := int(round(float(raw_contract) * completion_ratio))
	var tip_mult := 1.0 if is_fired else get_tip_bonus_multiplier(save)
	var shift_mood := int(call_state.get("mood", 60))
	if not is_fired and shift_mood >= 80:
		tip_mult += 0.15
	var adjusted_contract := int(round(float(prorated_contract) * tip_mult))
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
	nxt_save["mood"] = clampi(maxi(45, shift_mood), 25, 100)

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
		"aborted": false,
		"reason": "",
		"payout_rp": total_payout,
		"xp_gained": xp_gained,
		"fired": is_fired,
		"save": nxt_save,
		"shift": nxt_shift,
	}
