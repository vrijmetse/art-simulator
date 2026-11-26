class_name ArtRetention
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")
const WishlistStory := preload("res://src/core/wishlist_story.gd")

const STREAK_REWARDS := [
	{"day": 1, "rp": 15000, "xp": 5, "label_id": "Hari 1: Uang Jajan Awal", "label_en": "Day 1: Starter Snack Bonus"},
	{"day": 2, "rp": 10000, "xp": 15, "label_id": "Hari 2: Tambahan Pengalaman", "label_en": "Day 2: Experience Boost"},
	{"day": 3, "rp": 25000, "xp": 10, "label_id": "Hari 3: Bonus Transport", "label_en": "Day 3: Commute Bonus"},
	{"day": 4, "rp": 15000, "xp": 25, "label_id": "Hari 4: Semangat Kerja", "label_en": "Day 4: Work Spirit Boost"},
	{"day": 5, "rp": 40000, "xp": 15, "label_id": "Hari 5: Tabungan Mingguan", "label_en": "Day 5: Weekly Savings"},
	{"day": 6, "rp": 20000, "xp": 40, "label_id": "Hari 6: Latihan Ahli", "label_en": "Day 6: Pro Training"},
	{"day": 7, "rp": 75000, "xp": 50, "label_id": "Hari 7: Bonus Pekan Penuh!", "label_en": "Day 7: Full-Week Jackpot!"},
]

const MISSIONS_POOL := [
	{"id": "m_shifts", "event": "shifts", "target": 2, "rp": 25000, "xp": 20, "label_id": "Selesaikan 2 Shift Hari Ini", "label_en": "Complete 2 Shifts Today"},
	{"id": "m_neighbors", "event": "neighbors", "target": 3, "rp": 15000, "xp": 15, "label_id": "Sapa 3 Tetangga di Jalan", "label_en": "Greet 3 Neighbors Outside"},
	{"id": "m_calls", "event": "calls", "target": 2, "rp": 20000, "xp": 18, "label_id": "Jawab 2 Panggilan Majikan", "label_en": "Answer 2 Employer Calls"},
	{"id": "m_boosts", "event": "boosts", "target": 4, "rp": 15000, "xp": 15, "label_id": "Pakai Ketuk Cepat 4 Kali", "label_en": "Use Tap Boost 4 Times"},
	{"id": "m_chores", "event": "chores", "target": 6, "rp": 20000, "xp": 20, "label_id": "Bereskan 6 Tugas Rumah", "label_en": "Finish 6 Household Chores"},
]

const BADGES := {
	"first_shift": {"id": "first_shift", "xp": 25, "label_id": "Langkah Pertama", "label_en": "First Shift Done", "desc_id": "Menyelesaikan shift kerja pertamamu.", "desc_en": "Complete your very first shift."},
	"fast_worker": {"id": "fast_worker", "xp": 25, "label_id": "Tangan Cekatan", "label_en": "Quick Hands", "desc_id": "Gunakan Ketuk Cepat 5+ kali.", "desc_en": "Use Tap Boost 5+ times."},
	"friendly_art": {"id": "friendly_art", "xp": 25, "label_id": "Rukun Tetangga", "label_en": "Friendly Neighbor", "desc_id": "Sapa 3+ warga lingkungan.", "desc_en": "Greet 3+ neighborhood residents."},
	"rent_free": {"id": "rent_free", "xp": 25, "label_id": "Bebas Sewa Kos", "label_en": "Rent-Free Pro", "desc_id": "Tembus Perumahan Tipe 45 (Kamar ART sendiri).", "desc_en": "Unlock Tipe 45 Live-In ART room."},
	"dream_seeker": {"id": "dream_seeker", "xp": 25, "label_id": "Pemburu Impian", "label_en": "Dream Achiever", "desc_id": "Wujudkan minimal 1 Impian ART.", "desc_en": "Achieve at least 1 ART Dream."},
	"elite_star": {"id": "elite_star", "xp": 25, "label_id": "Bintang Cluster Elite", "label_en": "Elite Cluster Star", "desc_id": "Buka seluruh Impian ART & Cluster Elite.", "desc_en": "Unlock all ART Dreams & Elite Cluster."},
}

static func _day_number(date_str: String) -> int:
	if date_str.length() < 10:
		return -1
	var clean := date_str.left(10) + "T00:00:00"
	var unix := Time.get_unix_time_from_datetime_string(clean)
	if unix <= 0:
		return -1
	return int(unix / 86400)

static func _date_hash(date_str: String) -> int:
	var h := 0
	for i in range(date_str.length()):
		h = (h * 31 + date_str.unicode_at(i)) % 1000003
	return absi(h)

static func _ensure_missions_dict(raw_m: Variant, today_str: String) -> Dictionary:
	if typeof(raw_m) == TYPE_DICTIONARY:
		var d: Dictionary = raw_m
		var d_str := String(d.get("date", ""))
		var d_cur := _day_number(today_str)
		var d_old := _day_number(d_str)
		if d_str == today_str or (d_cur >= 0 and d_old >= 0 and d_cur < d_old):
			var prog: Dictionary = d.get("progress", {}).duplicate(true) if typeof(d.get("progress", null)) == TYPE_DICTIONARY else {}
			var claimed: Array = d.get("claimed", []).duplicate() if typeof(d.get("claimed", null)) == TYPE_ARRAY else []
			return {"date": d_str if not d_str.is_empty() else today_str, "progress": prog, "claimed": claimed}
	return {"date": today_str, "progress": {}, "claimed": []}

static func sync_daily_login(save: Dictionary, today_str: String) -> Dictionary:
	var nxt := save.duplicate(true)
	var last := String(nxt.get("last_login_date", ""))
	var cur_streak := clampi(int(nxt.get("login_streak", 0)), 0, 7)
	var d_today := _day_number(today_str)
	var d_last := _day_number(last)

	if last.is_empty() or d_last < 0 or d_today < 0:
		cur_streak = 1
		nxt["last_login_date"] = today_str
		nxt["daily_missions"] = _ensure_missions_dict({}, today_str)
	else:
		var diff := d_today - d_last
		if diff == 0:
			if cur_streak == 0:
				cur_streak = 1
			nxt["daily_missions"] = _ensure_missions_dict(nxt.get("daily_missions", {}), today_str)
		elif diff < 0:
			# Clock skew backwards: preserve streak safely
			if cur_streak == 0:
				cur_streak = 1
			nxt["daily_missions"] = _ensure_missions_dict(nxt.get("daily_missions", {}), today_str)
		elif diff == 1:
			cur_streak = 1 if cur_streak >= 7 else (cur_streak + 1)
			nxt["last_login_date"] = today_str
			nxt["daily_missions"] = _ensure_missions_dict({}, today_str)
		else:
			cur_streak = 1
			nxt["last_login_date"] = today_str
			nxt["daily_missions"] = _ensure_missions_dict({}, today_str)

	nxt["login_streak"] = clampi(cur_streak, 1, 7)
	var claimed_s := String(nxt.get("streak_claimed_date", ""))
	var d_claimed := _day_number(claimed_s)
	var can_claim := claimed_s != today_str
	if not claimed_s.is_empty() and d_today >= 0 and d_claimed >= 0 and d_today <= d_claimed:
		can_claim = false
	return {"save": nxt, "can_claim_streak": can_claim}

static func claim_streak_reward(save: Dictionary, today_str: String) -> Dictionary:
	var synced := sync_daily_login(save, today_str)
	var nxt: Dictionary = synced["save"]
	if not bool(synced["can_claim_streak"]):
		return {"ok": false, "reason": "already_claimed", "save": save}
	var streak_day := clampi(int(nxt.get("login_streak", 1)), 1, 7)
	var rw: Dictionary = STREAK_REWARDS[streak_day - 1]
	nxt["streak_claimed_date"] = today_str
	nxt["balance_rp"] = int(nxt.get("balance_rp", 0)) + int(rw["rp"])
	nxt["total_earnings_rp"] = int(nxt.get("total_earnings_rp", 0)) + int(rw["rp"])
	nxt["xp"] = int(nxt.get("xp", 0)) + int(rw["xp"])
	return {"ok": true, "reward": rw, "save": nxt}

static func _pick_daily_mission_configs(today_str: String) -> Array:
	var out: Array = []
	var seed_idx := _date_hash(today_str) % MISSIONS_POOL.size()
	for k in range(3):
		out.append(MISSIONS_POOL[(seed_idx + k) % MISSIONS_POOL.size()])
	return out

static func get_active_missions(save: Dictionary, today_str: String, locale: String = "id") -> Array:
	var dm := _ensure_missions_dict(save.get("daily_missions", {}), today_str)
	var prog: Dictionary = dm["progress"]
	var claimed: Array = dm["claimed"]
	var out: Array = []
	for cfg in _pick_daily_mission_configs(today_str):
		var mid := String(cfg["id"])
		var cur_v := mini(int(cfg["target"]), int(prog.get(mid, 0)))
		out.append({
			"id": mid,
			"event": String(cfg["event"]),
			"current": cur_v,
			"target": int(cfg["target"]),
			"done": cur_v >= int(cfg["target"]),
			"claimed": mid in claimed,
			"rp": int(cfg["rp"]),
			"xp": int(cfg["xp"]),
			"label": String(cfg["label_en"] if locale == "en" else cfg["label_id"]),
		})
	return out

static func record_mission_progress(save: Dictionary, event_key: String, amount: int, today_str: String) -> Dictionary:
	var nxt := save.duplicate(true)
	var dm := _ensure_missions_dict(nxt.get("daily_missions", {}), today_str)
	var prog: Dictionary = dm["progress"]
	for cfg in _pick_daily_mission_configs(today_str):
		if String(cfg["event"]) == event_key:
			var mid := String(cfg["id"])
			prog[mid] = mini(int(cfg["target"]), int(prog.get(mid, 0)) + maxi(0, amount))
	dm["progress"] = prog
	nxt["daily_missions"] = dm
	return nxt

static func claim_mission_reward(save: Dictionary, mission_id: String, today_str: String) -> Dictionary:
	var dm := _ensure_missions_dict(save.get("daily_missions", {}), today_str)
	var prog: Dictionary = dm["progress"]
	var claimed: Array = dm["claimed"]
	if mission_id in claimed:
		return {"ok": false, "reason": "already_claimed", "save": save}
	var found := {}
	for cfg in _pick_daily_mission_configs(today_str):
		if String(cfg["id"]) == mission_id:
			found = cfg
			break
	if found.is_empty():
		return {"ok": false, "reason": "not_active_today", "save": save}
	if int(prog.get(mission_id, 0)) < int(found["target"]):
		return {"ok": false, "reason": "not_completed", "save": save}
	var nxt := save.duplicate(true)
	claimed.append(mission_id)
	dm["claimed"] = claimed
	nxt["daily_missions"] = dm
	nxt["balance_rp"] = int(nxt.get("balance_rp", 0)) + int(found["rp"])
	nxt["total_earnings_rp"] = int(nxt.get("total_earnings_rp", 0)) + int(found["rp"])
	nxt["xp"] = int(nxt.get("xp", 0)) + int(found["xp"])
	return {"ok": true, "mission": found, "save": nxt}

static func has_unclaimed_daily_reward(save: Dictionary, today_str: String) -> bool:
	var claimed_s := String(save.get("streak_claimed_date", ""))
	var d_today := _day_number(today_str)
	var d_claimed := _day_number(claimed_s)
	var streak_open := claimed_s != today_str
	if not claimed_s.is_empty() and d_today >= 0 and d_claimed >= 0 and d_today <= d_claimed:
		streak_open = false
	if streak_open:
		return true
	for m in get_active_missions(save, today_str, "id"):
		if bool(m["done"]) and not bool(m["claimed"]):
			return true
	return false

static func get_shift_event(day: int, tier_id: String, locale: String = "id") -> Dictionary:
	var idx := posmod(maxi(1, day) + tier_id.length(), 4)
	match idx:
		1:
			return {
				"id": "arisan_ramai",
				"title": "Employer Gathering (+35% Contract Pay)" if locale == "en" else "Hari Arisan Majikan (+35% Gaji Kontrak)",
				"pay_mult": 1.35,
				"patience_mult": 0.85,
				"energy_mult": 1.0,
				"xp_mult": 1.0,
				"flat_bonus_rp": 0,
			}
		2:
			return {
				"id": "hujan_berkah",
				"title": "Cozy Rain Bonus (+Rp 10k Commute)" if locale == "en" else "Hujan Berkah (+Rp 10rb Transport)",
				"pay_mult": 1.0,
				"patience_mult": 1.0,
				"energy_mult": 0.9,
				"xp_mult": 1.0,
				"flat_bonus_rp": 10000,
			}
		3:
			return {
				"id": "tamu_keluarga",
				"title": "Family Visit (+25% Shift XP)" if locale == "en" else "Tamu Keluarga (+25% XP Shift)",
				"pay_mult": 1.0,
				"patience_mult": 1.0,
				"energy_mult": 1.0,
				"xp_mult": 1.25,
				"flat_bonus_rp": 0,
			}
		_:
			return {
				"id": "normal",
				"title": "Regular Workday" if locale == "en" else "Hari Kerja Normal",
				"pay_mult": 1.0,
				"patience_mult": 1.0,
				"energy_mult": 1.0,
				"xp_mult": 1.0,
				"flat_bonus_rp": 0,
			}

static func evaluate_badges(save: Dictionary) -> Dictionary:
	var nxt := save.duplicate(true)
	var unlocked: Array = nxt.get("unlocked_badges", []).duplicate() if typeof(nxt.get("unlocked_badges", null)) == TYPE_ARRAY else []
	var newly: Array = []
	var xp := int(nxt.get("xp", 0))
	var conds := {
		"first_shift": int(nxt.get("completed_shifts", 0)) >= 1,
		"fast_worker": int(nxt.get("shift_boost_count", 0)) >= 5,
		"friendly_art": (nxt.get("chatted_dates", {}) as Dictionary).size() >= 3,
		"rent_free": CareerTiers.can_access_tier("perumahan_45", xp),
		"dream_seeker": (nxt.get("unlocked_wishlist", []) as Array).size() >= 1,
		"elite_star": WishlistStory.is_epilogue_unlocked(nxt),
	}
	for bid in BADGES.keys():
		if bool(conds.get(bid, false)) and not (bid in unlocked):
			unlocked.append(bid)
			newly.append(BADGES[bid])
			nxt["xp"] = int(nxt.get("xp", 0)) + int(BADGES[bid]["xp"])
	nxt["unlocked_badges"] = unlocked
	return {"save": nxt, "newly_unlocked": newly}
