class_name ArtHouseholdDilemmas
extends RefCounted

const Progression := preload("res://src/core/progression.gd")

const DILEMMAS := {
	"dilemma_kos_student": {
		"id": "dilemma_kos_student",
		"tier_id": "kamar_kos",
		"speaker_id": "ibu_melati",
		"title_id": "Sisa Lauk Anak Kos",
		"title_en": "Boarders' Leftover Dinner",
		"prompt_id": "Dua mahasiswa kos sebelah belum sempat kiriman uang dari kampung dan bertanya pelan apakah nasi hangat sisa dapur boleh mereka makan.",
		"prompt_en": "Two students next door haven't received their family allowance yet and quietly ask if they can share the leftover warm rice from the kitchen.",
		"choices": [
			{
				"label_id": "Tanya Ibu Melati Baik-Baik (+Trust & +Mood)",
				"label_en": "Ask Ibu Melati Politely (+Trust & +Mood)",
				"delta_rp": 0, "xp": 20, "mood": 8, "trust": 8, "energy": 0,
				"outcome_id": "Ibu Melati tersenyum haru: \"Tentu boleh, Mbak! Terima kasih sudah jujur bilang.\" Anak kos makan kenyang malam ini.",
				"outcome_en": "Ibu Melati smiles warmly: 'Of course! Thank you for asking honestly.' The students eat happily tonight.",
			},
			{
				"label_id": "Bungkus Diam-Diam (+XP, Risiko Trust)",
				"label_en": "Pack It Quietly (+XP, Trust Risk)",
				"delta_rp": 0, "xp": 15, "mood": 5, "trust": -4, "energy": 0,
				"outcome_id": "Mereka berterima kasih, meski Ibu Melati sempat heran melihat rice cooker cepat kosong.",
				"outcome_en": "They're grateful, though Ibu Melati noticed the rice cooker emptied faster than usual.",
			},
		],
	},
	"dilemma_kampung_gosong": {
		"id": "dilemma_kampung_gosong",
		"tier_id": "kampung",
		"speaker_id": "adik_bima",
		"title_id": "Panci Sambal Gosong!",
		"title_en": "Burnt Sambal Pot!",
		"prompt_id": "Adik Bima tidak sengaja membiarkan panci sambal gosong tepat sebelum tamu arisan Ibu Tini datang! Dapur penuh asap tipis.",
		"prompt_en": "Adik Bima accidentally scorched the sambal pot right before Ibu Tini's neighborhood guests arrive! Smoke fills the kitchen.",
		"choices": [
			{
				"label_id": "Bantu Bersihkan & Masak Ulang (-8 Energi, +Rp 15.000)",
				"label_en": "Scrub & Recook Fast (-8 Energy, +Rp 15.000)",
				"delta_rp": 15000, "xp": 25, "mood": 6, "trust": 10, "energy": -8,
				"outcome_id": "Tangan cekatanmu menyelamatkan acara! Ibu Tini dan Bima sangat berterima kasih (+Rp 15.000).",
				"outcome_en": "Your quick rescue saved the gathering! Ibu Tini and Bima are deeply grateful (+Rp 15.000).",
			},
			{
				"label_id": "Fokus Tugas Utama Saja (Hemat Energi)",
				"label_en": "Stay on Main Chores (Save Energy)",
				"delta_rp": 0, "xp": 10, "mood": 0, "trust": -3, "energy": 0,
				"outcome_id": "Bima membereskan sendiri dengan gugup sebelum tamu datang.",
				"outcome_en": "Bima nervously cleaned it up himself before the guests knocked.",
			},
		],
	},
	"dilemma_p36_pecah": {
		"id": "dilemma_p36_pecah",
		"tier_id": "perumahan_36",
		"speaker_id": "ibu_sari",
		"title_id": "Bingkai Foto Retak",
		"title_en": "Cracked Family Frame",
		"prompt_id": "Saat mengelap meja ruang keluarga, kamu menemukan bingkai foto kenangan Pak Budi sudah retak di belakang vas bunga.",
		"prompt_en": "While dusting the living table, you notice Pak Budi's cherished family photo frame cracked behind the flower vase.",
		"choices": [
			{
				"label_id": "Jujur Lapor & Rapikan Rapi (+10 Trust, +20 XP)",
				"label_en": "Report Honestly & Tidy (+10 Trust, +20 XP)",
				"delta_rp": 0, "xp": 20, "mood": 6, "trust": 10, "energy": 0,
				"outcome_id": "Ibu Sari menghargai kejujuranmu: \"Untung Mbak kasih tahu biar kacanya tidak melukai tangan.\"",
				"outcome_en": "Ibu Sari values your honesty: 'Good thing you told me so nobody cuts a finger on the glass.'",
			},
			{
				"label_id": "Selotip Rapi Diam-Diam (+Rp 5.000, -4 Trust)",
				"label_en": "Tape It Quietly (+Rp 5.000, -4 Trust)",
				"delta_rp": 5000, "xp": 10, "mood": -2, "trust": -4, "energy": 0,
				"outcome_id": "Bingkai berdiri kembali, meski rasa mengganjal tetap terasa sepanjang shift.",
				"outcome_en": "The frame stands upright again, though a lingering unease stays with you.",
			},
		],
	},
	"dilemma_p45_curhat": {
		"id": "dilemma_p45_curhat",
		"tier_id": "perumahan_45",
		"speaker_id": "kakak_nadine",
		"title_id": "Keraguan Kakak Nadine",
		"title_en": "Kakak Nadine's Crossroads",
		"prompt_id": "Kakak Nadine bercerita pelan di teras — ia ragu antara lanjut mengejar beasiswa kuliah atau langsung bekerja bantu keluarga.",
		"prompt_en": "Kakak Nadine confides softly — she's torn between chasing her college scholarship or quitting early to work right away.",
		"choices": [
			{
				"label_id": "Semangati Kejar Beasiswa (+25 XP, +8 Mood)",
				"label_en": "Encourage Her Scholarship (+25 XP, +8 Mood)",
				"delta_rp": 0, "xp": 25, "mood": 8, "trust": 8, "energy": 0,
				"outcome_id": "Mata Nadine berbinar: \"Benar juga ya Mbak, ilmu itu bekal seumur hidup!\"",
				"outcome_en": "Nadine's eyes brighten: 'You're right — education is a lifelong anchor!'",
			},
			{
				"label_id": "Dengar Penuh Empati (+15 XP, +6 Mood)",
				"label_en": "Listen Empathetically (+15 XP, +6 Mood)",
				"delta_rp": 0, "xp": 15, "mood": 6, "trust": 6, "energy": 0,
				"outcome_id": "Kadang didengar tanpa dihakimi adalah dukungan terbaik.",
				"outcome_en": "Sometimes being listened to without judgment is the warmest support.",
			},
		],
	},
	"dilemma_elite_amplop": {
		"id": "dilemma_elite_amplop",
		"tier_id": "cluster_elite",
		"speaker_id": "ibu_citra",
		"title_id": "Amplop Tebal Terjatuh",
		"title_en": "Dropped Cash Envelope",
		"prompt_id": "Saat menyapu kolong sofa Cluster Elite, kamu menemukan amplop tebal bertuliskan \"Uang Tunai Tamu\" terjatuh di sudut karpet.",
		"prompt_en": "While sweeping beneath the Elite Cluster sofa, you find a thick envelope labeled 'Guest Cash' slipped into the corner.",
		"choices": [
			{
				"label_id": "Serahkan Langsung ke Ibu Citra (+Rp 50.000, +12 Trust)",
				"label_en": "Hand Directly to Ibu Citra (+Rp 50.000, +12 Trust)",
				"delta_rp": 50000, "xp": 30, "mood": 10, "trust": 12, "energy": 0,
				"outcome_id": "Ibu Citra terkesima dengan integritasmu dan memberi apresiasi langsung (+Rp 50.000)!",
				"outcome_en": "Ibu Citra is deeply moved by your integrity and rewards your honesty (+Rp 50.000)!",
			},
			{
				"label_id": "Letakkan Rapi di Meja Kerja (+15 XP, +4 Trust)",
				"label_en": "Place Neatly on Study Desk (+15 XP, +4 Trust)",
				"delta_rp": 0, "xp": 15, "mood": 4, "trust": 4, "energy": 0,
				"outcome_id": "Amplop aman di atas meja kerja dengan catatan kecil tulisanmu.",
				"outcome_en": "The envelope rests safely on the desk with your neat sticky note.",
			},
		],
	},
}

static func should_trigger(tier_id: String, elapsed_s: float, already_triggered: bool, completed_count: int, blocked_by_ui_or_event: bool) -> bool:
	if already_triggered or blocked_by_ui_or_event:
		return false
	if elapsed_s < 10.0 or completed_count < 1:
		return false
	return not pick_for_tier(tier_id).is_empty()

static func pick_for_tier(tier_id: String) -> Dictionary:
	for did in DILEMMAS.keys():
		var d: Dictionary = DILEMMAS[did]
		if String(d["tier_id"]) == tier_id:
			return d
	return {}

static func resolve_choice(save: Dictionary, call_state: Dictionary, shift: Dictionary, dilemma_id: String, choice_idx: int) -> Dictionary:
	if not DILEMMAS.has(dilemma_id):
		return {"ok": false, "reason": "unknown_dilemma", "save": save, "call_state": call_state, "shift": shift}
	var d: Dictionary = DILEMMAS[dilemma_id]
	var choices: Array = d.get("choices", [])
	if choice_idx < 0 or choice_idx >= choices.size():
		return {"ok": false, "reason": "invalid_choice", "save": save, "call_state": call_state, "shift": shift}

	var ch: Dictionary = choices[choice_idx]
	var nxt_sv := save.duplicate(true)
	var nxt_cs := call_state.duplicate(true)
	var nxt_sh := shift.duplicate(true)

	var resolved: Array = nxt_sv.get("resolved_dilemmas", []).duplicate()
	var first_time := not (dilemma_id in resolved)
	if first_time:
		resolved.append(dilemma_id)
		nxt_sv["resolved_dilemmas"] = resolved

	var delta_rp := int(ch.get("delta_rp", 0))
	nxt_sv["balance_rp"] = maxi(0, int(nxt_sv.get("balance_rp", 0)) + delta_rp)
	if delta_rp > 0:
		nxt_sv["total_earnings_rp"] = int(nxt_sv.get("total_earnings_rp", 0)) + delta_rp

	var xp_gain := int(ch.get("xp", 0)) if first_time else 0
	nxt_sv["xp"] = int(nxt_sv.get("xp", 0)) + xp_gain

	var max_e := Progression.get_max_energy(nxt_sv)
	var delta_e := int(ch.get("energy", 0))
	nxt_sv["energy"] = clampi(int(nxt_sv.get("energy", max_e)) + delta_e, 0, max_e)
	if not nxt_sh.is_empty():
		var sh_max := maxi(10, int(nxt_sh.get("max_energy", max_e)))
		nxt_sh["energy"] = clampi(int(nxt_sh.get("energy", sh_max)) + delta_e, 0, sh_max)

	nxt_sv["mood"] = clampi(int(nxt_sv.get("mood", 65)) + int(ch.get("mood", 0)), 0, 100)
	if not nxt_cs.is_empty():
		nxt_cs["mood"] = clampi(int(nxt_cs.get("mood", 60)) + int(ch.get("mood", 0)), 0, 100)
		nxt_cs["trust"] = clampi(int(nxt_cs.get("trust", 60)) + int(ch.get("trust", 0)), 0, 100)

	return {
		"ok": true,
		"first_time": first_time,
		"xp_gained": xp_gain,
		"delta_rp": delta_rp,
		"outcome_id": String(ch.get("outcome_id", "")),
		"outcome_en": String(ch.get("outcome_en", "")),
		"speaker_id": String(d.get("speaker_id", "player")),
		"save": nxt_sv,
		"call_state": nxt_cs,
		"shift": nxt_sh,
	}
