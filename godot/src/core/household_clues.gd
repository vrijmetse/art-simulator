class_name ArtHouseholdClues
extends RefCounted

const CLUE_XP_BONUS := 20
const CLUE_MOOD_BONUS := 5

const CLUES := {
	"clue_melati_foto": {
		"id": "clue_melati_foto",
		"tier_id": "kamar_kos",
		"title_id": "Foto Lawas Ibu Melati",
		"title_en": "Ibu Melati's Faded Photo",
		"story_id": "Di balik meja kos, foto tua Ibu Melati muda memegang ijazah guru. Ternyata kos sederhana ini dibangunnya dari uang pensiun guru SD demi menyekolahkan anak rantau.",
		"story_en": "Behind the desk sits a faded photo of young Ibu Melati holding a teaching diploma. She built this modest kos from her elementary school pension to shelter young city newcomers.",
	},
	"clue_kos_nota": {
		"id": "clue_kos_nota",
		"tier_id": "kamar_kos",
		"title_id": "Catatan Beras Anak Kos",
		"title_en": "Boarders' Rice Ledger",
		"story_id": "Ibu Melati mencoret utang makan dua mahasiswa yang belum kirim uang dari kampung: \"Lunas — doakan saja ibu sehat.\" Hati hangat seketika.",
		"story_en": "Ibu Melati crossed out meal tabs for two struggling students: 'Paid — just wish me good health.' A quiet reminder of community kindness.",
	},
	"clue_bima_crayon": {
		"id": "clue_bima_crayon",
		"tier_id": "kampung",
		"title_id": "Gambar Krayon Adik Bima",
		"title_en": "Adik Bima's Crayon Drawing",
		"story_id": "Di bawah bantal sofa ada gambar krayon empat orang plus satu figur berseragam celemek: \"Ini Mbak ART yang selalu masak nasi enak!\"",
		"story_en": "Under the sofa cushion lies a crayon sketch of the family plus one apron-clad figure: 'Our helpful sister who always makes warm rice!'",
	},
	"clue_agus_bengkel": {
		"id": "clue_agus_bengkel",
		"tier_id": "kampung",
		"title_id": "Kuitansi Bengkel Pak Agus",
		"title_en": "Pak Agus's Repair Receipt",
		"story_id": "Tumpukan kuitansi bengkel motor ojek yang menumpuk, tapi amplop THR untukmu tetap terpisah rapi bertuliskan nama lengkapmu.",
		"story_en": "A thick stack of motorcycle repair bills sits beside a neatly sealed THR envelope labeled carefully with your name.",
	},
	"clue_sari_tiket": {
		"id": "clue_sari_tiket",
		"tier_id": "perumahan_36",
		"title_id": "Tiket Mudik Tahun Lalu",
		"title_en": "Last Year's Train Ticket",
		"story_id": "Tiket kereta ekonomi yang disimpan rapi di laci Ibu Sari — keluarganya pun dulu perantau yang menabung bertahun-tahun demi rumah Tipe 36 ini.",
		"story_en": "A worn economy train stub tucked in Ibu Sari's drawer — her family once came from a small town too, saving years for this Tipe 36 home.",
	},
	"clue_budi_kopi": {
		"id": "clue_budi_kopi",
		"tier_id": "perumahan_36",
		"title_id": "Catatan Lembur Pak Budi",
		"title_en": "Pak Budi's Late-Shift Note",
		"story_id": "Post-it kecil di meja dapur: \"Jangan lupa tidur cukup ya Mbak, sisa kue bolu di kulkas buat Mbak.\" Kerja kerasmu benar-benar dihargai.",
		"story_en": "A small kitchen sticky note: 'Don't forget to rest well — leftover sponge cake in the fridge is for you.' Your care is genuinely noticed.",
	},
	"clue_rina_surat": {
		"id": "clue_rina_surat",
		"tier_id": "perumahan_45",
		"title_id": "Pesan Mantan ART Sebelumnya",
		"title_en": "Note from the Previous Homekeeper",
		"story_id": "Catatan kecil di balik lemari kamar ART: \"Semangat! Saya kerja di sini 2 tahun sampai berhasil buka usaha jahit di kampung.\"",
		"story_en": "A tiny note taped inside the ART room wardrobe: 'Stay strong! I worked here 2 years until I opened my own tailoring shop back home.'",
	},
	"clue_hendra_piagam": {
		"id": "clue_hendra_piagam",
		"tier_id": "perumahan_45",
		"title_id": "Piagam Lomba Sains",
		"title_en": "Science Fair Certificate",
		"story_id": "Kakak Nadine menulis ucapan terima kasih di belakang piagamnya karena selalu disiapkan bekal pagi tepat waktu sebelum ujian.",
		"story_en": "Kakak Nadine wrote a thank-you note on the back of her trophy certificate for always having warm breakfast ready before exam mornings.",
	},
	"clue_citra_lukisan": {
		"id": "clue_citra_lukisan",
		"tier_id": "cluster_elite",
		"title_id": "Sketsa Desa Ibu Citra",
		"title_en": "Ibu Citra's Village Sketch",
		"story_id": "Di balik rumah mewah ini, Ibu Citra diam-diam melukis sawah masa kecilnya setiap malam — rumah besar pun tetap rindu ketenangan kampung.",
		"story_en": "Inside this grand mansion, Ibu Citra quietly paints rice fields from her childhood every night — even wealth misses simple peace.",
	},
	"clue_elite_wisuda": {
		"id": "clue_elite_wisuda",
		"tier_id": "cluster_elite",
		"title_id": "Surat Rekomendasi Profesional",
		"title_en": "Executive Reference Letter",
		"story_id": "Draf surat rekomendasi bertanda tangan keluarga Cluster Elite yang memuji kejujuran dan kepemimpinanmu — modal besar membuka agensi sendiri kelak.",
		"story_en": "A signed reference letter praising your integrity and household leadership — a golden credential when you launch your own agency.",
	},
}

const STAGE_CLUE_POS := {
	"kamar_kos": Vector3(-1.35, 0.0, -1.15),
	"kampung": Vector3(-0.15, 0.0, -0.35),
	"perumahan_36": Vector3(0.45, 0.0, -1.75),
	"perumahan_45": Vector3(0.45, 0.0, -1.75),
	"cluster_elite": Vector3(-0.85, 0.0, -1.85),
}

static func get_clue_pos(tier_id: String) -> Vector3:
	return STAGE_CLUE_POS.get(tier_id, Vector3(-1.35, 0.0, -1.15))

static func pick_clue_for_shift(tier_id: String, unlocked_clues: Array, day: int = 1) -> Dictionary:
	var pool: Array = []
	for cid in CLUES.keys():
		var item: Dictionary = CLUES[cid]
		if String(item["tier_id"]) == tier_id and not (cid in unlocked_clues):
			pool.append(item)
	if pool.is_empty():
		return {}
	var idx := posmod(maxi(0, day - 1), pool.size())
	return pool[idx]

static func collect_clue(save: Dictionary, clue_id: String) -> Dictionary:
	if not CLUES.has(clue_id):
		return {"ok": false, "reason": "unknown_clue", "save": save}
	var cur_unlocked: Array = save.get("unlocked_clues", [])
	if clue_id in cur_unlocked:
		return {"ok": false, "reason": "already_unlocked", "save": save}
	var nxt := save.duplicate(true)
	var arr: Array = nxt.get("unlocked_clues", []).duplicate()
	arr.append(clue_id)
	nxt["unlocked_clues"] = arr
	nxt["xp"] = int(nxt.get("xp", 0)) + CLUE_XP_BONUS
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + CLUE_MOOD_BONUS, 0, 100)
	return {"ok": true, "clue": CLUES[clue_id], "xp_bonus": CLUE_XP_BONUS, "save": nxt}
