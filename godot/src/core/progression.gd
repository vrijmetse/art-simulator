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
		"login_streak": 0,
		"last_login_date": "",
		"streak_claimed_date": "",
		"daily_missions": {},
		"unlocked_badges": [],
		"shift_boost_count": 0,
		"calls_answered_count": 0,
		"energy": 100,
		"worked_since_sleep": false,
		"game_minutes": 360,
		"prayer_reminders": true,
		"prayed_day": 1,
		"prayed_today": [],
		"thr_claimed_cycle": -1,
		"takjil_claimed_day": 0,
		"remittance_sent_rp": 0,
		"remittance_deadline_day": 10,
		"courier_orders": [],
		"debt_book": [],
		"guide_seen": false,
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

	var tier := CareerTiers.get_tier(String(save.get("active_tier_id", "kamar_kos")))
	var cur_day := maxi(1, int(save.get("day", 1)))
	var cycle_day := ((cur_day - 1) % 30) + 1
	var is_ramadhan := (cycle_day >= 10 and cycle_day <= 15)
	var meal_cost := 0
	if not is_fired and not is_ramadhan and not bool(tier.get("live_in_room_provided", false)) and cur_day >= 3 and (int(save.get("balance_rp", 0)) + total_payout) >= 15000:
		meal_cost = 8000

	var nxt_save := save.duplicate(true)
	nxt_save["balance_rp"] = maxi(0, int(nxt_save.get("balance_rp", 0)) + total_payout - meal_cost)
	nxt_save["total_earnings_rp"] = int(nxt_save.get("total_earnings_rp", 0)) + total_payout
	nxt_save["xp"] = int(nxt_save.get("xp", 0)) + xp_gained
	nxt_save["day"] = cur_day + 1
	nxt_save["completed_shifts"] = int(nxt_save.get("completed_shifts", 0)) + (0 if is_fired else 1)
	nxt_save["fired_count"] = int(nxt_save.get("fired_count", 0)) + (1 if is_fired else 0)
	nxt_save["mood"] = clampi(maxi(45, shift_mood), 25, 100)
	var max_e := get_max_energy(nxt_save)
	nxt_save["energy"] = clampi(int(shift.get("energy", max_e)), 0, max_e)
	nxt_save["worked_since_sleep"] = true
	nxt_save["game_minutes"] = clampi(int(nxt_save.get("game_minutes", 360)) + 240, 270, 1320)

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
		"meal_cost_rp": meal_cost,
		"xp_gained": xp_gained,
		"fired": is_fired,
		"save": nxt_save,
		"shift": nxt_shift,
	}

const SUPPLY_SHOP_ITEMS := {
	"kopi_tubruk": {
		"id": "kopi_tubruk",
		"cost_rp": 12000,
		"energy_gain": 22,
		"mood_gain": 8,
		"label_id": "Kopi Tubruk Hangat",
		"label_en": "Hot Village Coffee",
		"desc_id": "+22 Energi, +8% Semangat saat paket tiba.",
		"desc_en": "+22 Energy, +8% Mood on delivery.",
	},
	"vitamin_energi": {
		"id": "vitamin_energi",
		"cost_rp": 22000,
		"energy_gain": 40,
		"mood_gain": 12,
		"label_id": "Jamu & Vitamin Stamina",
		"label_en": "Herbal Stamina Pack",
		"desc_id": "+40 Energi, +12% Semangat untuk shift padat.",
		"desc_en": "+40 Energy, +12% Mood for busy shifts.",
	},
	"detergen_wangi": {
		"id": "detergen_wangi",
		"cost_rp": 18000,
		"energy_gain": 10,
		"mood_gain": 15,
		"label_id": "Pewangi & Detergen Premium",
		"label_en": "Floral Laundry Kit",
		"desc_id": "+15% Semangat & +10 Energi setelah kerja.",
		"desc_en": "+15% Mood & +10 Energy after chores.",
	},
	"paket_sembako": {
		"id": "paket_sembako",
		"cost_rp": 35000,
		"energy_gain": 55,
		"mood_gain": 20,
		"label_id": "Paket Makan & Lauk Kos",
		"label_en": "Meal & Pantry Box",
		"desc_id": "+55 Energi & +20% Semangat penuh nutrisi.",
		"desc_en": "+55 Energy & +20% Mood full meal pack.",
	},
}

const MAX_KASBON_DEBT_RP := 100000

static func preview_balance_after(save: Dictionary, cost_rp: int) -> Dictionary:
	var bal := int(save.get("balance_rp", 0))
	var cost := maxi(0, cost_rp)
	return {
		"can_afford": bal >= cost,
		"balance_before": bal,
		"cost_rp": cost,
		"balance_after": bal - cost,
	}

static func checkout_supply_cart(save: Dictionary, cart: Dictionary) -> Dictionary:
	if cart.is_empty():
		return {"ok": false, "reason": "empty_cart", "save": save}
	var total_cost := 0
	var items_summary: Array = []
	var total_qty := 0
	for raw_k in cart.keys():
		var item_id := String(raw_k)
		if not SUPPLY_SHOP_ITEMS.has(item_id):
			return {"ok": false, "reason": "unknown_item", "save": save}
		var raw_q: Variant = cart[raw_k]
		if typeof(raw_q) != TYPE_INT and typeof(raw_q) != TYPE_FLOAT:
			return {"ok": false, "reason": "invalid_qty", "save": save}
		var qty := int(raw_q)
		if qty <= 0 or qty > 20:
			return {"ok": false, "reason": "invalid_qty", "save": save}
		var item: Dictionary = SUPPLY_SHOP_ITEMS[item_id]
		total_cost += int(item["cost_rp"]) * qty
		total_qty += qty
		items_summary.append({"id": item_id, "qty": qty})
	if total_qty <= 0 or total_cost <= 0:
		return {"ok": false, "reason": "empty_cart", "save": save}
	var bal := int(save.get("balance_rp", 0))
	if bal < total_cost:
		return {"ok": false, "reason": "insufficient_funds", "save": save}
	var nxt := save.duplicate(true)
	nxt["balance_rp"] = bal - total_cost
	var orders: Array = nxt.get("courier_orders", []).duplicate(true)
	var first_id := String(items_summary[0]["id"])
	var first_item: Dictionary = SUPPLY_SHOP_ITEMS[first_id]
	var oid := "ord_%d_%d" % [int(nxt.get("day", 1)), orders.size() + 1 + int(nxt.get("game_minutes", 360))]
	orders.append({
		"id": oid,
		"items": items_summary,
		"remaining_s": 16.0,
		"total_cost_rp": total_cost,
		"label_id": String(first_item["label_id"]) if items_summary.size() == 1 else ("Paket Belanja (%d item)" % total_qty),
		"label_en": String(first_item["label_en"]) if items_summary.size() == 1 else ("Supply Pack (%d items)" % total_qty),
	})
	nxt["courier_orders"] = orders
	return {"ok": true, "order_id": oid, "total_cost_rp": total_cost, "save": nxt}

static func tick_courier_orders(save: Dictionary, dt: float) -> Dictionary:
	var orders: Array = save.get("courier_orders", [])
	if orders.is_empty():
		return save
	var nxt := save.duplicate(true)
	var nxt_orders: Array = nxt.get("courier_orders", [])
	for o in nxt_orders:
		if typeof(o) == TYPE_DICTIONARY:
			o["remaining_s"] = maxf(0.0, float(o.get("remaining_s", 0.0)) - maxf(0.0, dt))
	nxt["courier_orders"] = nxt_orders
	return nxt

static func claim_courier_delivery(save: Dictionary, order_id: String) -> Dictionary:
	var orders: Array = save.get("courier_orders", [])
	var idx := -1
	for i in range(orders.size()):
		if typeof(orders[i]) == TYPE_DICTIONARY and String(orders[i].get("id", "")) == order_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "order_not_found", "save": save}
	var ord: Dictionary = orders[idx]
	if float(ord.get("remaining_s", 0.0)) > 0.01:
		return {"ok": false, "reason": "in_transit", "save": save}
	var nxt := save.duplicate(true)
	var nxt_orders: Array = nxt.get("courier_orders", []).duplicate(true)
	nxt_orders.remove_at(idx)
	nxt["courier_orders"] = nxt_orders
	var e_gain := 0
	var m_gain := 0
	for entry in ord.get("items", []):
		if typeof(entry) == TYPE_DICTIONARY:
			var it_id := String(entry.get("id", ""))
			var qty := maxi(1, int(entry.get("qty", 1)))
			if SUPPLY_SHOP_ITEMS.has(it_id):
				e_gain += int(SUPPLY_SHOP_ITEMS[it_id]["energy_gain"]) * qty
				m_gain += int(SUPPLY_SHOP_ITEMS[it_id]["mood_gain"]) * qty
	var max_e := get_max_energy(nxt)
	nxt["energy"] = clampi(int(nxt.get("energy", max_e)) + e_gain, 0, max_e)
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + m_gain, 0, 100)
	return {"ok": true, "energy_gain": e_gain, "mood_gain": m_gain, "save": nxt}

static func get_unpaid_kasbon_total(save: Dictionary) -> int:
	var tot := 0
	for row in save.get("debt_book", []):
		if typeof(row) == TYPE_DICTIONARY and not bool(row.get("paid", false)):
			tot += maxi(0, int(row.get("amount_rp", 0)))
	return tot

static func record_kasbon(save: Dictionary, who: String, amount_rp: int) -> Dictionary:
	if amount_rp <= 0:
		return {"ok": false, "reason": "invalid_amount", "save": save}
	var cur_unpaid := get_unpaid_kasbon_total(save)
	if cur_unpaid + amount_rp > MAX_KASBON_DEBT_RP:
		return {"ok": false, "reason": "debt_cap_exceeded", "save": save}
	var clean_who := who.strip_edges().left(32)
	if clean_who.is_empty():
		clean_who = "Warung Bu Tini"
	var nxt := save.duplicate(true)
	var book: Array = nxt.get("debt_book", []).duplicate(true)
	var did := "kb_%d_%d" % [int(nxt.get("day", 1)), book.size() + 1]
	book.append({
		"id": did,
		"who": clean_who,
		"amount_rp": amount_rp,
		"day": int(nxt.get("day", 1)),
		"paid": false,
	})
	nxt["debt_book"] = book
	nxt["balance_rp"] = int(nxt.get("balance_rp", 0)) + amount_rp
	return {"ok": true, "debt_id": did, "save": nxt}

static func pay_kasbon(save: Dictionary, debt_id: String) -> Dictionary:
	var book: Array = save.get("debt_book", [])
	var idx := -1
	for i in range(book.size()):
		if typeof(book[i]) == TYPE_DICTIONARY and String(book[i].get("id", "")) == debt_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "not_found", "save": save}
	var row: Dictionary = book[idx]
	if bool(row.get("paid", false)):
		return {"ok": false, "reason": "already_paid", "save": save}
	var amt := maxi(0, int(row.get("amount_rp", 0)))
	var bal := int(save.get("balance_rp", 0))
	if bal < amt:
		return {"ok": false, "reason": "insufficient_funds", "save": save}
	var nxt := save.duplicate(true)
	var nxt_book: Array = nxt.get("debt_book", []).duplicate(true)
	nxt_book[idx]["paid"] = true
	nxt["debt_book"] = nxt_book
	nxt["balance_rp"] = bal - amt
	nxt["xp"] = int(nxt.get("xp", 0)) + 8
	return {"ok": true, "amount_rp": amt, "save": nxt}

static func get_spotlight_tutorial_steps(locale: String = "id") -> Array:
	var en := (locale == "en")
	return [
		{
			"step": 0,
			"target": "shift",
			"title": "Start Shift" if en else "Mulai Shift",
			"text": "Tap Start Shift (or step outside) to go to your employer's house and earn Rp." if en else "Ketuk Mulai Shift (atau keluar kamar) untuk bantu rumah majikan dan dapat gaji Rp.",
		},
		{
			"step": 1,
			"target": "tasks",
			"title": "Tasks & Progress" if en else "Daftar Tugas",
			"text": "This is your Task List: tap to expand chores, rewards, and tips while working." if en else "Ini daftar Tugasmu: ketuk untuk melihat rincian pekerjaan dan bonus hadiahnya.",
		},
		{
			"step": 2,
			"target": "phone",
			"title": "Sari's Phone (HP)" if en else "HP Sari",
			"text": "Open your Phone for Bank Desaku transfers, Supply Shop, and Messages." if en else "Buka HP untuk kirim uang di Bank Desaku, belanja perlengkapan, dan cek pesan.",
		},
		{
			"step": 3,
			"target": "upgrade",
			"title": "Upgrade Room" if en else "Upgrade Kamar",
			"text": "Upgrade your kos room to boost max Energy, Mood, and daily tips!" if en else "Upgrade kamar kos untuk menambah Energi maksimal, Semangat, dan tip harian!",
		},
	]

static func get_phone_layout_mode(viewport_size: Vector2) -> String:
	if viewport_size.y <= 500.0 and viewport_size.x > viewport_size.y:
		return "landscape"
	return "portrait"
