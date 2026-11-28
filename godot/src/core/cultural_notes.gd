class_name ArtCulturalNotes
extends RefCounted

const NOTES := [
	{
		"id": "kos",
		"title_id": "Kamar Kos (Kos-kosan)",
		"title_en": "Kos-kosan (Indonesian Boarding House)",
		"body_id": "Kamar sewa bulanan yang akrab bagi perantau di kota besar Indonesia. Biasanya punya dapur bersama dan ibu kos yang hangat sekaligus tegas soal sewa.",
		"body_en": "Affordable monthly boarding rooms where young workers and students live when moving to Indonesian cities — complete with a caring, watchful Ibu Kos.",
	},
	{
		"id": "art",
		"title_id": "ART (Asisten Rumah Tangga)",
		"title_en": "ART (Domestic Homekeeper)",
		"body_id": "Tenaga profesional yang merawat rumah tangga dengan penuh ketekunan dan kepercayaan, mulai dari pekerja harian hingga tinggal bersama keluarga majikan.",
		"body_en": "Skilled domestic professionals who keep Indonesian households thriving — from daily neighborhood helpers to trusted live-in homekeepers.",
	},
	{
		"id": "thr",
		"title_id": "THR (Tunjangan Hari Raya)",
		"title_en": "THR (Eid Holiday Bonus)",
		"body_id": "Bonus tahunan wajib menjelang Lebaran/Idul Fitri senilai tambahan penghasilan bagi pekerja yang sudah mengabdi dengan tekun.",
		"body_en": "Indonesia's beloved annual festive bonus paid ahead of Eid al-Fitr to honor a worker's dedication throughout the year.",
	},
	{
		"id": "jemuran",
		"title_id": "Drama Jemuran & Hujan Tropis",
		"title_en": "Jemuran (Outdoor Laundry Dash)",
		"body_id": "Di daerah tropis, hujan deras datang tiba-tiba! Momen legendaris semua rumah Indonesia adalah lari menyelamatkan jemuran saat guntur terdengar.",
		"body_en": "Tropical downpours strike in seconds! Sprinting to rescue clothes from the outdoor clothesline at the first rumble of thunder is a universal Indonesian ritual.",
	},
	{
		"id": "kasbon",
		"title_id": "Kasbon Warung / Majikan",
		"title_en": "Kasbon (Zero-Interest Pay Advance)",
		"body_id": "Pinjaman talangan tanpa bunga berbasis saling percaya saat kebutuhan mendadak datang sebelum tanggal gajian.",
		"body_en": "A trust-based, zero-interest salary advance or local shop tab that helps workers bridge tight days before payday.",
	},
	{
		"id": "pak_rt",
		"title_id": "Pak RT & Gotong Royong",
		"title_en": "Pak RT (Neighborhood Elder)",
		"body_id": "Ketua Rukun Tetangga adalah pemimpin warga di tingkat gang yang menjaga keamanan, silaturahmi, dan semangat gotong royong.",
		"body_en": "The elected neighborhood block leader who coordinates community care, safety, and mutual aid (gotong royong) across every Indonesian street.",
	},
	{
		"id": "mudik",
		"title_id": "Mudik & Kirim Kampung",
		"title_en": "Mudik & Remittance Home",
		"body_id": "Menabung demi mengirim uang bulanan dan pulang ke kampung halaman menemui orang tua adalah alasan terkuat para anak rantau.",
		"body_en": "Sending monthly earnings back to family and saving up for the joyful homecoming journey (Mudik) anchors every migrant worker's story.",
	},
	{
		"id": "warung",
		"title_id": "Warung & Tukang Sayur",
		"title_en": "Warung (Neighborhood Corner Shop)",
		"body_id": "Toko kelontong kecil di sudut gang yang menjadi pusat kebutuhan harian, kopi tubruk, gorengan hangat, sekaligus tempat berbagi kabar warga.",
		"body_en": "Family-run corner shops offering daily groceries, hot coffee, snacks, and neighborhood warmth on every Indonesian street.",
	},
]

static func get_notes(locale: String = "id") -> Array:
	var out: Array = []
	var is_en := locale == "en"
	for item in NOTES:
		out.append({
			"id": String(item["id"]),
			"title": String(item["title_en"] if is_en else item["title_id"]),
			"body": String(item["body_en"] if is_en else item["body_id"]),
		})
	return out
