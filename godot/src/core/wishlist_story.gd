class_name ArtWishlistStory
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")

const WISHLIST_ITEMS := {
	"kirim_kampung": {
		"id": "kirim_kampung",
		"cost_rp": 150000,
		"xp_bonus": 60,
		"mood_bonus": 5,
		"label_id": "Kirim Uang ke Kampung",
		"label_en": "Send Money Home",
		"desc_id": "Bantu orang tua di kampung halaman.",
		"desc_en": "Support family back home.",
	},
	"hp_baru": {
		"id": "hp_baru",
		"cost_rp": 450000,
		"xp_bonus": 120,
		"mood_bonus": 8,
		"label_id": "HP Baru Layar Jernih",
		"label_en": "New Smartphone",
		"desc_id": "Video call keluarga makin lancar.",
		"desc_en": "Clearer video calls with family.",
	},
	"tabung_kontrakan": {
		"id": "tabung_kontrakan",
		"cost_rp": 1200000,
		"xp_bonus": 250,
		"mood_bonus": 12,
		"label_id": "Tabungan Kontrakan Sendiri",
		"label_en": "Own Rental Deposit",
		"desc_id": "Punya tempat tinggal yang lebih lega.",
		"desc_en": "Save up for a spacious place.",
	},
	"motor_matic": {
		"id": "motor_matic",
		"cost_rp": 3500000,
		"xp_bonus": 500,
		"mood_bonus": 18,
		"label_id": "Motor Matic Sendiri",
		"label_en": "Own Scooter",
		"desc_id": "Pulang-pergi kerja tanpa kehujanan.",
		"desc_en": "Commute easily without waiting.",
	},
}

const STORY_CHAPTERS := {
	"kamar_kos": {
		"id": "ch_kamar_kos",
		"tier_id": "kamar_kos",
		"title_id": "Bab 1: Merantau di Kamar Kos",
		"title_en": "Chapter 1: Starting in a Kos Room",
		"body_id": "Hari pertamamu sebagai ART di kota besar. Dari kamar kos sederhana ini, setiap sapuan dan kerja keras adalah langkah menuju impianmu.",
		"body_en": "Your first day as a domestic worker in the city. From this modest kos room, every chore brings you closer to your dreams.",
	},
	"kampung": {
		"id": "ch_kampung",
		"tier_id": "kampung",
		"title_id": "Bab 2: Dipercaya di Gang Kampung",
		"title_en": "Chapter 2: Trusted in Gang Kampung",
		"body_id": "Kerja kerasmu mulai dikenal warga gang. Kini kamu dipercaya membantu rumah keluarga Pak Agus di lingkungan kampung yang ramah.",
		"body_en": "Your reliability is getting noticed. You are now trusted to care for Pak Agus's home in the friendly kampung.",
	},
	"perumahan_36": {
		"id": "ch_perumahan_36",
		"tier_id": "perumahan_36",
		"title_id": "Bab 3: Hangatnya Perumahan Tipe 36",
		"title_en": "Chapter 3: Warmth of Tipe 36 Housing",
		"body_id": "Masuk ke komplek perumahan rapi dengan dapur ramai dan cucian harian. Kecekatanmu membuat keluarga Ibu Sari nyaman.",
		"body_en": "Moving up to a neat residential street with a busy kitchen and laundry. Your skill keeps Ibu Sari's household running smoothly.",
	},
	"perumahan_45": {
		"id": "ch_perumahan_45",
		"tier_id": "perumahan_45",
		"title_id": "Bab 4: Menginap di Rumah Tipe 45",
		"title_en": "Chapter 4: Live-In at Tipe 45 Home",
		"body_id": "Kini kamu mendapat kamar ART sendiri bebas biaya sewa kos! Standar kerja lebih tinggi dengan gaji jauh lebih besar.",
		"body_en": "You now have your own live-in ART room with zero kos rent! Higher expectations come with much higher pay.",
	},
	"cluster_elite": {
		"id": "ch_cluster_elite",
		"tier_id": "cluster_elite",
		"title_id": "Bab 5: Puncak Karier di Cluster Elite",
		"title_en": "Chapter 5: Peak Career at Cluster Elite",
		"body_id": "Dari kamar kos sederhana hingga rumah mewah Cluster Elite—semua berkat ketekunanmu. Kamu resmi menjadi ART profesional terbaik!",
		"body_en": "From a simple kos room to an Elite Cluster mansion—all thanks to your dedication. You are now a top-tier professional!",
	},
}

const STORY_EPILOGUE := {
	"id": "ch_epilogue",
	"tier_id": "epilogue",
	"title_id": "Epilog: Kisah Sukses Sang ART Teladan",
	"title_en": "Epilogue: Story of a Model Homekeeper",
	"body_id": "Cluster Elite sudah dipercaya padamu dan semua Impian ART telah terwujud—uang kiriman kampung, HP baru, tabungan kontrakan, hingga motor sendiri! Perjalananmu dari kamar kos sederhana kini menjadi inspirasi seluruh lingkungan.",
	"body_en": "You mastered the Elite Cluster and achieved every ART Dream—supporting family back home, a new phone, rental savings, and your own scooter! Your journey from a humble kos room now inspires the entire neighborhood.",
}

static func is_epilogue_unlocked(save: Dictionary) -> bool:
	var xp := int(save.get("xp", 0))
	if not CareerTiers.can_access_tier("cluster_elite", xp):
		return false
	var unlocked: Array = save.get("unlocked_wishlist", [])
	for raw_id in WISHLIST_ITEMS.keys():
		if not (String(raw_id) in unlocked):
			return false
	return true

static func get_unseen_epilogue(save: Dictionary) -> Dictionary:
	if not is_epilogue_unlocked(save):
		return {}
	var seen: Array = save.get("seen_chapters", [])
	if String(STORY_EPILOGUE["id"]) in seen:
		return {}
	return STORY_EPILOGUE

static func get_storybook_entries(save: Dictionary, locale: String = "id") -> Array:
	var out: Array = []
	var xp := int(save.get("xp", 0))
	for t in CareerTiers.TIERS:
		var tid := String(t["id"])
		var ch: Dictionary = STORY_CHAPTERS.get(tid, {})
		if ch.is_empty():
			continue
		var unlocked := CareerTiers.can_access_tier(tid, xp)
		out.append({
			"id": String(ch["id"]),
			"tier_id": tid,
			"unlocked": unlocked,
			"min_xp": int(t["min_xp"]),
			"title": String(ch["title_en"] if locale == "en" else ch["title_id"]),
			"body": String(ch["body_en"] if locale == "en" else ch["body_id"]),
			"chapter": ch,
		})
	out.append({
		"id": String(STORY_EPILOGUE["id"]),
		"tier_id": "epilogue",
		"unlocked": is_epilogue_unlocked(save),
		"min_xp": 1400,
		"title": String(STORY_EPILOGUE["title_en"] if locale == "en" else STORY_EPILOGUE["title_id"]),
		"body": String(STORY_EPILOGUE["body_en"] if locale == "en" else STORY_EPILOGUE["body_id"]),
		"chapter": STORY_EPILOGUE,
	})
	return out

static func buy_wishlist_item(save: Dictionary, item_id: String) -> Dictionary:
	if not WISHLIST_ITEMS.has(item_id):
		return {"ok": false, "reason": "unknown_item", "save": save}
	var unlocked: Array = save.get("unlocked_wishlist", [])
	if item_id in unlocked:
		return {"ok": false, "reason": "already_unlocked", "save": save}
	var item: Dictionary = WISHLIST_ITEMS[item_id]
	var cost := int(item["cost_rp"])
	var bal := int(save.get("balance_rp", 0))
	if bal < cost:
		return {"ok": false, "reason": "insufficient_funds", "save": save}
	var nxt := save.duplicate(true)
	nxt["balance_rp"] = bal - cost
	nxt["xp"] = int(nxt.get("xp", 0)) + int(item["xp_bonus"])
	var nxt_unlocked: Array = nxt.get("unlocked_wishlist", []).duplicate()
	nxt_unlocked.append(item_id)
	nxt["unlocked_wishlist"] = nxt_unlocked
	return {"ok": true, "item": item, "save": nxt}

static func get_wishlist_mood_bonus(save: Dictionary) -> int:
	var bonus := 0
	var seen := {}
	var unlocked: Array = save.get("unlocked_wishlist", [])
	for raw_id in unlocked:
		var item_id := String(raw_id)
		if WISHLIST_ITEMS.has(item_id) and not seen.has(item_id):
			seen[item_id] = true
			bonus += int(WISHLIST_ITEMS[item_id].get("mood_bonus", 0))
	return bonus

static func get_unseen_chapter(save: Dictionary, tier_id: String = "") -> Dictionary:
	var tid := tier_id if not tier_id.is_empty() else String(save.get("active_tier_id", "kamar_kos"))
	if not STORY_CHAPTERS.has(tid):
		return {}
	var ch: Dictionary = STORY_CHAPTERS[tid]
	var ch_id := String(ch["id"])
	var seen: Array = save.get("seen_chapters", [])
	if ch_id in seen:
		return {}
	return ch

static func mark_chapter_seen(save: Dictionary, chapter_id: String) -> Dictionary:
	var nxt := save.duplicate(true)
	var seen: Array = nxt.get("seen_chapters", []).duplicate()
	if not chapter_id.is_empty() and not (chapter_id in seen):
		seen.append(chapter_id)
	nxt["seen_chapters"] = seen
	return nxt

static func get_newly_unlocked_chapter_tier(prev_xp: int, new_xp: int, save: Dictionary) -> String:
	var found := ""
	for t in CareerTiers.TIERS:
		var tid := String(t["id"])
		if CareerTiers.can_access_tier(tid, new_xp) and not CareerTiers.can_access_tier(tid, prev_xp):
			if not get_unseen_chapter(save, tid).is_empty():
				found = tid
	return found

static func get_tutorial_hint(step: int, locale: String = "id") -> String:
	match step:
		0:
			return "Step 1/4: Step out of your room to the street." if locale == "en" else "Langkah 1/4: Keluar dari kamar kos menuju jalanan."
		1:
			return "Step 2/4: Greet a neighbor or enter Employer's House." if locale == "en" else "Langkah 2/4: Sapa tetangga atau masuk ke Rumah Majikan."
		2:
			return "Step 3/4: Complete a household task [E]." if locale == "en" else "Langkah 3/4: Kerjakan tugas rumah tangga [E]."
		3:
			return "Step 4/4: Finish your shift when tasks are done." if locale == "en" else "Langkah 4/4: Selesaikan shift setelah tugas beres."
		_:
			return ""

static func advance_tutorial(save: Dictionary, target_step: int = -1) -> Dictionary:
	var nxt := save.duplicate(true)
	var cur := clampi(int(nxt.get("tutorial_step", 0)), 0, 4)
	if cur >= 4:
		nxt["tutorial_step"] = 4
		return nxt
	if target_step >= 0:
		nxt["tutorial_step"] = clampi(maxi(cur, target_step), 0, 4)
	else:
		nxt["tutorial_step"] = clampi(cur + 1, 0, 4)
	return nxt
