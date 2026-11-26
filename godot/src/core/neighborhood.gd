class_name ArtNeighborhood

const NEIGHBORS := [
	{
		"id": "ibu_sari",
		"name_id": "Ibu Sari",
		"role_id": "Istri / Pemilik Rumah",
		"role_en": "Wife / Homeowner",
		"greeting_id": "Alhamdulillah ruang tamu dan teras sudah bersih sekali. Ini uang makan siang buatmu ya!",
		"greeting_en": "The living room and porch look spotless! Here is some lunch money for you.",
		"tip_rp": 5500,
		"start_x": -2.4,
		"lane_z": 1.35,
		"speed": 0.42,
		"skin": "#DFAC8E",
		"shirt": "#E07A5F",
		"hair": "#3D2C2E",
	},
	{
		"id": "adik_bima",
		"name_id": "Adik Bima",
		"role_id": "Anak Pemilik Rumah",
		"role_en": "Homeowner's Son",
		"greeting_id": "Kakak ART! Makasih udah rapihin kamar belajarku. Ini koin jajan buat Kakak!",
		"greeting_en": "Big Sis! Thanks for tidying up my study desk. Here is a snack coin for you!",
		"tip_rp": 4500,
		"start_x": 0.1,
		"lane_z": 1.65,
		"speed": 0.52,
		"skin": "#E6B89C",
		"shirt": "#4EA8DE",
		"hair": "#2B2D42",
	},
	{
		"id": "pak_budi",
		"name_id": "Pak Budi",
		"role_id": "Suami / Kepala Keluarga",
		"role_en": "Husband / Head of House",
		"greeting_id": "Rumah terasa nyaman setiap kami pulang kerja. Ini bonus kopi ya!",
		"greeting_en": "Home always feels cozy when we get back from work. Here is a coffee bonus!",
		"tip_rp": 6000,
		"start_x": 2.6,
		"lane_z": 1.25,
		"speed": 0.46,
		"skin": "#D49E7D",
		"shirt": "#2A9D8F",
		"hair": "#2B2D42",
	},
	{
		"id": "pak_rt",
		"name_id": "Pak RT",
		"role_id": "Ketua RT Setempat",
		"role_en": "Neighborhood Chief",
		"greeting_id": "Warga makin rukun kalau lingkungan bersih. Ini ada uang kas buat jajanmu!",
		"greeting_en": "The neighborhood thrives when it is clean. Here is a little snack money for you!",
		"tip_rp": 5000,
		"start_x": -3.2,
		"lane_z": 1.45,
		"speed": 0.38,
		"skin": "#C99674",
		"shirt": "#52796F",
		"hair": "#3D3D3D",
	},
	{
		"id": "bang_ojek",
		"name_id": "Bang Ojek",
		"role_id": "Tukang Ojek Pangkalan",
		"role_en": "Motorcycle Taxi Rider",
		"greeting_id": "Pagi Mbak! Mau nitip beli gorengan sekalian lewat? Ini kembaliannya buatmu.",
		"greeting_en": "Morning! Want me to grab some fritters on my route? Keep the change!",
		"tip_rp": 4000,
		"start_x": 1.8,
		"lane_z": 1.55,
		"speed": 0.55,
		"skin": "#C68B67",
		"shirt": "#2D6A4F",
		"hair": "#1B1B1E",
	},
	{
		"id": "kurir_paket",
		"name_id": "Kurir Paket",
		"role_id": "Kurir Ekspedisi",
		"role_en": "Parcel Courier",
		"greeting_id": "Permisi, paket buat rumah sebelah sudah dititip ya. Makasih udah bantu jaga!",
		"greeting_en": "Excuse me, I left the neighbor's parcel safely. Thanks for keeping an eye out!",
		"tip_rp": 4500,
		"start_x": -1.1,
		"lane_z": 1.30,
		"speed": 0.50,
		"skin": "#D8A484",
		"shirt": "#F77F00",
		"hair": "#2B2D42",
	},
	{
		"id": "anak_sekolah",
		"name_id": "Anak Sekolah",
		"role_id": "Pelajar SMP",
		"role_en": "Junior High Student",
		"greeting_id": "Kakak! Jalanannya udah rapi banget pagi ini. Ini ada permen sama uang jajan!",
		"greeting_en": "Big Sis! The street looks so tidy this morning. Here is some pocket money!",
		"tip_rp": 3500,
		"start_x": 3.6,
		"lane_z": 1.60,
		"speed": 0.58,
		"skin": "#E6B89C",
		"shirt": "#457B9D",
		"hair": "#1D1E2C",
	},
]

static func create_patrols() -> Array:
	var out: Array = []
	for i in range(NEIGHBORS.size()):
		var spec: Dictionary = NEIGHBORS[i]
		var dir: int = 1 if (i % 2 == 0) else -1
		out.append({
			"spec": spec,
			"x": float(spec["start_x"]),
			"z": float(spec["lane_z"]),
			"dir": dir,
			"talking": false,
		})
	return out

static func claim_tip(state: Dictionary, npc_id: String, date_key: String) -> Dictionary:
	var found := {}
	for spec in NEIGHBORS:
		if spec["id"] == npc_id:
			found = spec
			break
	if found.is_empty():
		return {"claimed": false, "tip_rp": 0, "state": state}
	var chatted: Dictionary = state.get("chatted_dates", {})
	if chatted.get(npc_id, "") == date_key:
		return {"claimed": false, "tip_rp": 0, "state": state}
	var next := state.duplicate(true)
	var next_chatted: Dictionary = chatted.duplicate()
	next_chatted[npc_id] = date_key
	next["chatted_dates"] = next_chatted
	next["balance_rp"] = int(state.get("balance_rp", 0)) + int(found["tip_rp"])
	next["xp"] = int(state.get("xp", 0)) + 10
	return {"claimed": true, "tip_rp": int(found["tip_rp"]), "state": next}
