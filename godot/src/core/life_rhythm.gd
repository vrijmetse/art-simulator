class_name ArtLifeRhythm
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")

const PRAYER_SCHEDULE := [
	{"id": "subuh", "minute": 285, "label_id": "Subuh", "label_en": "Fajr"},
	{"id": "dzuhur", "minute": 720, "label_id": "Dzuhur", "label_en": "Dhuhr"},
	{"id": "ashar", "minute": 915, "label_id": "Ashar", "label_en": "Asr"},
	{"id": "maghrib", "minute": 1080, "label_id": "Maghrib", "label_en": "Maghrib"},
	{"id": "isya", "minute": 1155, "label_id": "Isya", "label_en": "Isha"},
]

static func format_clock(minutes: int) -> String:
	var m := clampi(minutes, 0, 1439)
	return "%02d:%02d" % [int(m / 60), m % 60]

static func get_phase_from_minutes(minutes: int) -> String:
	var m := clampi(minutes, 0, 1439)
	if m < 630:
		return "pagi"
	if m < 870:
		return "siang"
	if m < 1080:
		return "sore"
	return "malam"

static func is_late_night(minutes: int) -> bool:
	return clampi(minutes, 0, 1439) >= 1290

static func get_cycle_index(day: int) -> int:
	return int((maxi(1, day) - 1) / 30)

static func get_season(day: int) -> String:
	var cycle_day := ((maxi(1, day) - 1) % 30) + 1
	if cycle_day >= 10 and cycle_day <= 15:
		return "ramadhan"
	if cycle_day == 16:
		return "lebaran"
	return "biasa"

static func get_thr_bonus_rp(tier_id: String) -> int:
	match tier_id:
		"cluster_elite":
			return 300000
		"perumahan_45":
			return 225000
		_:
			return 150000

static func check_prayer_trigger(prev_min: int, cur_min: int, prayed_day: int, day: int, prayed_today: Array, enabled: bool) -> Dictionary:
	if not enabled or cur_min <= prev_min:
		return {"triggered": false}
	var active_prayed: Array = prayed_today if prayed_day == day else []
	for p in PRAYER_SCHEDULE:
		var pm := int(p["minute"])
		var pid := String(p["id"])
		if prev_min < pm and cur_min >= pm and not (pid in active_prayed):
			return {
				"triggered": true,
				"id": pid,
				"minute": pm,
				"label_id": String(p["label_id"]),
				"label_en": String(p["label_en"]),
			}
	return {"triggered": false}

static func _get_max_energy_for_save(save: Dictionary) -> int:
	var owned: Array = save.get("owned_upgrades", [])
	return 115 if ("kasur_empuk" in owned) else 100

static func claim_takjil(save: Dictionary, today_day: int) -> Dictionary:
	if get_season(today_day) != "ramadhan":
		return {"ok": false, "reason": "not_ramadhan", "save": save}
	if int(save.get("takjil_claimed_day", 0)) == today_day:
		return {"ok": false, "reason": "already_claimed", "save": save}
	var nxt := save.duplicate(true)
	var max_e := _get_max_energy_for_save(nxt)
	nxt["takjil_claimed_day"] = today_day
	nxt["energy"] = mini(max_e, int(nxt.get("energy", max_e)) + 20)
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + 15, 0, 100)
	return {"ok": true, "save": nxt}

static func perform_prayer(save: Dictionary, prayer_id: String, today_day: int) -> Dictionary:
	var pid := prayer_id.strip_edges().to_lower()
	var valid := false
	for p in PRAYER_SCHEDULE:
		if String(p["id"]) == pid:
			valid = true
			break
	if not valid:
		return {"ok": false, "reason": "invalid_prayer", "save": save}
	var prayed_day := int(save.get("prayed_day", 0))
	var prayed_list: Array = save.get("prayed_today", []).duplicate() if prayed_day == today_day else []
	if pid in prayed_list:
		return {"ok": false, "reason": "already_prayed", "save": save}

	var nxt := save.duplicate(true)
	prayed_list.append(pid)
	nxt["prayed_day"] = today_day
	nxt["prayed_today"] = prayed_list
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + 12, 0, 100)
	nxt["xp"] = int(nxt.get("xp", 0)) + 5

	var got_takjil := false
	if pid == "maghrib" and get_season(today_day) == "ramadhan":
		var tak := claim_takjil(nxt, today_day)
		if bool(tak["ok"]):
			nxt = tak["save"]
			got_takjil = true

	return {"ok": true, "prayer_id": pid, "got_takjil": got_takjil, "save": nxt}

static func claim_thr_if_eligible(save: Dictionary) -> Dictionary:
	var d := maxi(1, int(save.get("day", 1)))
	if get_season(d) != "lebaran":
		return {"ok": false, "bonus_rp": 0, "save": save}
	var cyc := get_cycle_index(d)
	if int(save.get("thr_claimed_cycle", -1)) == cyc:
		return {"ok": false, "bonus_rp": 0, "save": save}
	var tier_id := String(save.get("active_tier_id", "kamar_kos"))
	var bonus := get_thr_bonus_rp(tier_id)
	var nxt := save.duplicate(true)
	nxt["thr_claimed_cycle"] = cyc
	nxt["balance_rp"] = int(nxt.get("balance_rp", 0)) + bonus
	nxt["total_earnings_rp"] = int(nxt.get("total_earnings_rp", 0)) + bonus
	return {"ok": true, "bonus_rp": bonus, "save": nxt}

static func sleep_in_bed(save: Dictionary, owned_upgrades: Array) -> Dictionary:
	var nxt := save.duplicate(true)
	var max_e := 115 if ("kasur_empuk" in owned_upgrades or "kasur_empuk" in nxt.get("owned_upgrades", [])) else 100
	var mood_gain := 22
	if "kasur_empuk" in owned_upgrades or "kasur_empuk" in nxt.get("owned_upgrades", []):
		mood_gain += 6
	if "ac_hemat" in owned_upgrades or "ac_hemat" in nxt.get("owned_upgrades", []):
		mood_gain += 4

	var cur_day := maxi(1, int(nxt.get("day", 1)))
	if not bool(nxt.get("worked_since_sleep", false)):
		cur_day += 1
	nxt["day"] = cur_day
	nxt["worked_since_sleep"] = false
	nxt["energy"] = max_e
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + mood_gain, 0, 100)
	nxt["prayed_day"] = cur_day
	nxt["prayed_today"] = []
	nxt["game_minutes"] = 270 if get_season(cur_day) == "ramadhan" else 360

	var thr_res := claim_thr_if_eligible(nxt)
	nxt = thr_res["save"]
	return {
		"ok": true,
		"day": cur_day,
		"energy": max_e,
		"thr_bonus_rp": int(thr_res.get("bonus_rp", 0)),
		"season": get_season(cur_day),
		"save": nxt,
	}
