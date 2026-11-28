class_name ArtAgencyOps
extends RefCounted

const WishlistStory := preload("res://src/core/wishlist_story.gd")

const ROOKIE_POOL := {
	"art_nia": {
		"id": "art_nia",
		"cost_rp": 400000,
		"daily_income_rp": 35000,
		"label_id": "Mbak Nia (Spesialis Sapu & Rapikan)",
		"label_en": "Mbak Nia (Sweep & Tidy Specialist)",
		"desc_id": "Menangani kontrak kos & kampung — setor bersih +Rp 35.000/hari.",
		"desc_en": "Handles kos & kampung contracts — +Rp 35.000/day agency revenue.",
	},
	"art_tono": {
		"id": "art_tono",
		"cost_rp": 550000,
		"daily_income_rp": 50000,
		"label_id": "Mas Tono (Kebun, Cuci & Jemuran)",
		"label_en": "Mas Tono (Garden & Laundry Pro)",
		"desc_id": "Siaga antar-jemput cucian & taman Tipe 36 — setor +Rp 50.000/hari.",
		"desc_en": "Covers Tipe 36 laundry & garden shifts — +Rp 50.000/day revenue.",
	},
	"art_lestari": {
		"id": "art_lestari",
		"cost_rp": 750000,
		"daily_income_rp": 75000,
		"label_id": "Mbak Lestari (Chef & Cluster Elite)",
		"label_en": "Mbak Lestari (Elite Chef & Homekeeper)",
		"desc_id": "Dipercaya di Cluster Elite — setor bersih +Rp 75.000/hari!",
		"desc_en": "Trusted at Elite Cluster — +Rp 75.000/day agency revenue!",
	},
}

static func hire_rookie(save: Dictionary, rookie_id: String) -> Dictionary:
	if not WishlistStory.is_epilogue_unlocked(save):
		return {"ok": false, "reason": "epilogue_locked", "save": save}
	if not ROOKIE_POOL.has(rookie_id):
		return {"ok": false, "reason": "unknown_rookie", "save": save}
	var hired: Array = save.get("hired_agency_arts", [])
	if rookie_id in hired:
		return {"ok": false, "reason": "already_hired", "save": save}
	var item: Dictionary = ROOKIE_POOL[rookie_id]
	var cost := int(item["cost_rp"])
	var bal := int(save.get("balance_rp", 0))
	if bal < cost:
		return {"ok": false, "reason": "insufficient_balance", "save": save}
	var nxt := save.duplicate(true)
	nxt["balance_rp"] = bal - cost
	var arr: Array = nxt.get("hired_agency_arts", []).duplicate()
	arr.append(rookie_id)
	nxt["hired_agency_arts"] = arr
	nxt["xp"] = int(nxt.get("xp", 0)) + 40
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + 8, 0, 100)
	return {"ok": true, "cost_rp": cost, "daily_income_rp": int(item["daily_income_rp"]), "save": nxt}

static func get_agency_daily_income(save: Dictionary) -> int:
	var total := 0
	var hired: Array = save.get("hired_agency_arts", [])
	for raw_id in hired:
		var rid := String(raw_id)
		if ROOKIE_POOL.has(rid):
			total += int(ROOKIE_POOL[rid]["daily_income_rp"])
	return total
